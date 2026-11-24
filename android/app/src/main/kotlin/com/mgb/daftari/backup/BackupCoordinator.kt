package com.mgb.daftari.backup

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkRequest
import kotlinx.coroutines.CompletableDeferred
import java.io.File
import java.io.RandomAccessFile
import java.nio.channels.FileLock
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Process-wide coordinator shared between the foreground [MainActivity] engine
 * and background WorkManager [BackupWorker] headless Flutter engines.
 *
 * Each work request and bridge instance binds its own database name, secure
 * storage namespace and unique WorkManager queue name so an isolated test
 * fixture and an ordinary debug backup job can even overlap concurrently
 * without cross-contaminating ledgers, credentials, locks or successor queues.
 */
object BackupCoordinator {
    const val CHANNEL_NAME = "com.mgb.daftari/backup"
    const val UNIQUE_WORK_NAME = "com.mgb.daftari.cloud_backup.scheduled"
    const val WORK_TAG = "com.mgb.daftari.cloud_backup"
    const val TARGET_TAG_PREFIX = "com.mgb.daftari.cloud_backup.target:"
    const val INPUT_WORKER_MODE = "worker_mode"
    const val INPUT_TEST_DB_NAME = "test_db_name"
    const val INPUT_TEST_STORAGE_NAMESPACE = "test_storage_namespace"
    const val INPUT_UNIQUE_WORK_NAME = "unique_work_name"
    const val MODE_PRODUCTION = "production"

    private const val LOCK_FILE_NAME = "daftari_cloud_backup.lock"

    data class WorkerRequestBinding(
        val uniqueWorkName: String = UNIQUE_WORK_NAME,
        val databaseName: String? = null,
        val storageNamespace: String? = null,
    )

    private class RunLockScopeState(val lockFileName: String) {
        var runLockOwner: String? = null
        var lockFileStream: RandomAccessFile? = null
        var lockFileLock: FileLock? = null

        fun releaseFileLock() {
            try {
                lockFileLock?.release()
            } catch (_: Exception) {
            }
            try {
                lockFileStream?.close()
            } catch (_: Exception) {
            }
            lockFileLock = null
            lockFileStream = null
        }
    }

    private class CommitGateScopeState {
        val mutex = ReentrantLock()
        val commitReleased = mutex.newCondition()
        var sessionEpoch: Int = 0
        var pendingInvalidations: Int = 0
        val activeCommitOwners = mutableSetOf<String>()
        val activeInvalidationOwners = mutableMapOf<String, Int>()
    }

    private class TestBarrierScopeState {
        var armedStage: String? = null
        var pausedLatch: CountDownLatch? = null
        var releaseLatch: CountDownLatch? = null
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val scheduleMutex = ReentrantLock()
    private val runLockMutex = ReentrantLock()
    private val runLockScopes = ConcurrentHashMap<String, RunLockScopeState>()
    private val ownerLockScopes = ConcurrentHashMap<String, String>()

    private val commitScopes = ConcurrentHashMap<String, CommitGateScopeState>()
    private val ownerCommitScopes = ConcurrentHashMap<String, String>()

    private val pendingWorkers =
        ConcurrentHashMap<String, CompletableDeferred<ListenableWorker.Result>>()
    private val workerBindings = ConcurrentHashMap<String, WorkerRequestBinding>()
    private val foregroundHandlers = CopyOnWriteArrayList<BackupChannelHandler>()

    private val testBarrierMutex = ReentrantLock()
    private val testBarrierScopes = ConcurrentHashMap<String, TestBarrierScopeState>()

    fun isDebuggable(context: Context): Boolean =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    fun registerForegroundHandler(handler: BackupChannelHandler) {
        foregroundHandlers.addIfAbsent(handler)
    }

    fun unregisterForegroundHandler(handler: BackupChannelHandler) {
        foregroundHandlers.remove(handler)
    }

    fun notifyForegroundStateChanged() {
        mainHandler.post {
            for (handler in foregroundHandlers) {
                handler.notifyBackupStateChanged()
            }
        }
    }

    fun resolveWorkName(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): String {
        if (!isDebuggable(context)) return UNIQUE_WORK_NAME
        val explicit = requestedWorkName?.trim()?.takeIf { it.isNotEmpty() }
        if (explicit != null) return explicit
        return workerBindings[ownerId]?.uniqueWorkName ?: UNIQUE_WORK_NAME
    }

    fun resolveBinding(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
        requestedDatabaseName: String? = null,
        requestedStorageNamespace: String? = null,
    ): WorkerRequestBinding {
        if (!isDebuggable(context)) {
            return WorkerRequestBinding()
        }
        val workerBound = workerBindings[ownerId]
        val workName = requestedWorkName?.trim()?.takeIf { it.isNotEmpty() }
            ?: workerBound?.uniqueWorkName
            ?: UNIQUE_WORK_NAME
        val dbName = requestedDatabaseName?.trim()?.takeIf { it.isNotEmpty() }
            ?: workerBound?.databaseName
        val storageNs = requestedStorageNamespace?.trim()?.takeIf { it.isNotEmpty() }
            ?: workerBound?.storageNamespace
        return WorkerRequestBinding(
            uniqueWorkName = workName,
            databaseName = dbName,
            storageNamespace = storageNs,
        )
    }

    private fun lockFileNameForScope(scopeWorkName: String): String {
        if (scopeWorkName == UNIQUE_WORK_NAME) return LOCK_FILE_NAME
        val safeSuffix = scopeWorkName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return "daftari_cloud_backup_$safeSuffix.lock"
    }

    private fun runLockScopeFor(scopeWorkName: String): RunLockScopeState =
        runLockScopes.getOrPut(scopeWorkName) {
            RunLockScopeState(lockFileNameForScope(scopeWorkName))
        }

    private fun commitScopeFor(scopeWorkName: String): CommitGateScopeState =
        commitScopes.getOrPut(scopeWorkName) { CommitGateScopeState() }

    fun tryAcquireRunLock(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): Boolean {
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        val acquired = runLockMutex.withLock {
            val scope = runLockScopeFor(scopeName)
            if (scope.runLockOwner != null) {
                return@withLock false
            }
            val lockFile = File(context.filesDir, scope.lockFileName)
            var stream: RandomAccessFile? = null
            var fileLock: FileLock? = null
            try {
                stream = RandomAccessFile(lockFile, "rw")
                fileLock = stream.channel.tryLock()
                if (fileLock == null) {
                    stream.close()
                    return@withLock false
                }
                scope.lockFileStream = stream
                scope.lockFileLock = fileLock
                scope.runLockOwner = ownerId
                ownerLockScopes[ownerId] = scopeName
                true
            } catch (_: Exception) {
                try {
                    fileLock?.release()
                } catch (_: Exception) {
                }
                try {
                    stream?.close()
                } catch (_: Exception) {
                }
                false
            }
        }
        if (acquired) {
            notifyForegroundStateChanged()
        }
        return acquired
    }

    fun releaseRunLock(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        val released = runLockMutex.withLock {
            val scopeName = ownerLockScopes[ownerId]
                ?: resolveWorkName(context, ownerId, requestedWorkName)
            val scope = runLockScopeFor(scopeName)
            if (scope.runLockOwner != ownerId) {
                return@withLock false
            }
            scope.releaseFileLock()
            scope.runLockOwner = null
            ownerLockScopes.remove(ownerId)
            true
        }
        if (released) {
            notifyForegroundStateChanged()
        }
    }

    fun isRunLocked(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): Boolean {
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        return runLockMutex.withLock {
            runLockScopeFor(scopeName).runLockOwner != null
        }
    }

    fun readSessionEpoch(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): Int {
        val scope = commitScopeFor(resolveWorkName(context, ownerId, requestedWorkName))
        return scope.mutex.withLock { scope.sessionEpoch }
    }

    fun tryEnterCommit(
        context: Context,
        ownerId: String,
        expectedEpoch: Int,
        requestedWorkName: String? = null,
    ): Boolean {
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        val scope = commitScopeFor(scopeName)
        return scope.mutex.withLock {
            if (scope.pendingInvalidations > 0 || scope.sessionEpoch != expectedEpoch) {
                return@withLock false
            }
            scope.activeCommitOwners.add(ownerId)
            ownerCommitScopes[ownerId] = scopeName
            true
        }
    }

    fun exitCommit(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        val scopeName = ownerCommitScopes.remove(ownerId)
            ?: resolveWorkName(context, ownerId, requestedWorkName)
        val scope = commitScopeFor(scopeName)
        scope.mutex.withLock {
            if (scope.activeCommitOwners.remove(ownerId) &&
                scope.activeCommitOwners.isEmpty()
            ) {
                scope.commitReleased.signalAll()
            }
        }
    }

    /**
     * Must be invoked off the Android main thread so waiting for an active
     * worker SQLite commit never blocks the UI thread.
     */
    fun beginSessionInvalidation(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        val scope = commitScopeFor(scopeName)
        scope.mutex.withLock {
            scope.pendingInvalidations++
            scope.activeInvalidationOwners[ownerId] =
                (scope.activeInvalidationOwners[ownerId] ?: 0) + 1
            ownerCommitScopes[ownerId] = scopeName
            while (scope.activeCommitOwners.isNotEmpty()) {
                scope.commitReleased.await()
            }
        }
    }

    fun endSessionInvalidation(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        val scopeName = ownerCommitScopes[ownerId]
            ?: resolveWorkName(context, ownerId, requestedWorkName)
        val scope = commitScopeFor(scopeName)
        scope.mutex.withLock {
            scope.sessionEpoch++
            val current = scope.activeInvalidationOwners[ownerId] ?: 0
            if (current <= 1) {
                scope.activeInvalidationOwners.remove(ownerId)
                if (!scope.activeCommitOwners.contains(ownerId)) {
                    ownerCommitScopes.remove(ownerId)
                }
            } else {
                scope.activeInvalidationOwners[ownerId] = current - 1
            }
            if (scope.pendingInvalidations > 0) {
                scope.pendingInvalidations--
            }
        }
    }

    fun releaseAllForOwner(context: Context, ownerId: String) {
        releaseRunLock(context, ownerId)
        for (scope in commitScopes.values) {
            scope.mutex.withLock {
                if (scope.activeCommitOwners.remove(ownerId) &&
                    scope.activeCommitOwners.isEmpty()
                ) {
                    scope.commitReleased.signalAll()
                }
                val leakedInvalidations =
                    scope.activeInvalidationOwners.remove(ownerId) ?: 0
                if (leakedInvalidations > 0) {
                    scope.sessionEpoch++
                    scope.pendingInvalidations =
                        (scope.pendingInvalidations - leakedInvalidations).coerceAtLeast(0)
                }
            }
        }
        ownerCommitScopes.remove(ownerId)
    }

    private fun buildTargetTag(schedule: String?, nextDueAtEpochMs: Long?): String? {
        val cleanSchedule = schedule?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val dueAt = nextDueAtEpochMs ?: return null
        return "$TARGET_TAG_PREFIX$cleanSchedule:$dueAt"
    }

    private fun buildWorkerInputData(
        context: Context,
        workerMode: String,
        binding: WorkerRequestBinding,
    ): Data {
        val builder = Data.Builder().putString(INPUT_WORKER_MODE, workerMode)
        if (isDebuggable(context)) {
            if (!binding.databaseName.isNullOrBlank()) {
                builder.putString(INPUT_TEST_DB_NAME, binding.databaseName)
            }
            if (!binding.storageNamespace.isNullOrBlank()) {
                builder.putString(INPUT_TEST_STORAGE_NAMESPACE, binding.storageNamespace)
            }
            if (binding.uniqueWorkName.isNotBlank() &&
                binding.uniqueWorkName != UNIQUE_WORK_NAME
            ) {
                builder.putString(INPUT_UNIQUE_WORK_NAME, binding.uniqueWorkName)
            }
        }
        return builder.build()
    }

    private fun computeEffectiveDelayMs(delayMs: Long, nextDueAtEpochMs: Long?): Long {
        if (nextDueAtEpochMs != null) {
            return (nextDueAtEpochMs - System.currentTimeMillis()).coerceAtLeast(0L)
        }
        return delayMs.coerceAtLeast(0L)
    }

    private fun buildScheduledRequest(
        context: Context,
        delayMs: Long,
        nextDueAtEpochMs: Long?,
        targetTag: String?,
        binding: WorkerRequestBinding,
    ): OneTimeWorkRequest {
        val effectiveDelayMs = computeEffectiveDelayMs(delayMs, nextDueAtEpochMs)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val builder = OneTimeWorkRequestBuilder<BackupWorker>()
            .setInitialDelay(effectiveDelayMs, TimeUnit.MILLISECONDS)
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS,
            )
            .setInputData(buildWorkerInputData(context, MODE_PRODUCTION, binding))
            .addTag(WORK_TAG)
        if (!targetTag.isNullOrBlank()) {
            builder.addTag(targetTag)
        }
        return builder.build()
    }

    fun syncSchedule(
        context: Context,
        ownerId: String,
        delayMs: Long,
        schedule: String? = null,
        nextDueAtEpochMs: Long? = null,
        requestedWorkName: String? = null,
        requestedDatabaseName: String? = null,
        requestedStorageNamespace: String? = null,
    ) {
        val binding = resolveBinding(
            context = context,
            ownerId = ownerId,
            requestedWorkName = requestedWorkName,
            requestedDatabaseName = requestedDatabaseName,
            requestedStorageNamespace = requestedStorageNamespace,
        )
        val workName = binding.uniqueWorkName
        scheduleMutex.withLock {
            val workManager = WorkManager.getInstance(context)
            val infos = workManager.getWorkInfosForUniqueWork(workName).get()
            val unfinished = infos.filter { !it.state.isFinished }
            val targetTag = buildTargetTag(schedule, nextDueAtEpochMs)

            // When a worker on this queue is currently RUNNING, never cancel
            // the running worker. If the worker has not yet enqueued a BLOCKED
            // successor, let the finishing worker read the latest committed
            // schedule and due time directly from SQLite after acknowledgment
            // (P12-15). If a BLOCKED successor was already appended and the
            // user changed the schedule before doWork() returned, replace only
            // that BLOCKED successor at the new absolute due time.
            val runningWorkers = unfinished.filter { it.state == WorkInfo.State.RUNNING }
            if (runningWorkers.isNotEmpty()) {
                val nonRunningUnfinished =
                    unfinished.filter { it.state != WorkInfo.State.RUNNING }
                if (nonRunningUnfinished.isEmpty()) {
                    return@withLock
                }
                if (targetTag != null &&
                    nonRunningUnfinished.size == 1 &&
                    nonRunningUnfinished.single().tags.contains(targetTag)
                ) {
                    return@withLock
                }
                for (queued in nonRunningUnfinished) {
                    workManager.cancelWorkById(queued.id)
                }
                val request = buildScheduledRequest(
                    context = context,
                    delayMs = delayMs,
                    nextDueAtEpochMs = nextDueAtEpochMs,
                    targetTag = targetTag,
                    binding = binding,
                )
                workManager.enqueueUniqueWork(
                    workName,
                    ExistingWorkPolicy.APPEND_OR_REPLACE,
                    request,
                )
                return@withLock
            }

            // Preserve work in progress when the same schedule target is already enqueued.
            if (targetTag != null &&
                unfinished.size == 1 &&
                unfinished.single().tags.contains(targetTag)
            ) {
                return@withLock
            }

            val request = buildScheduledRequest(
                context = context,
                delayMs = delayMs,
                nextDueAtEpochMs = nextDueAtEpochMs,
                targetTag = targetTag,
                binding = binding,
            )
            workManager.enqueueUniqueWork(
                workName,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }

    /**
     * Called by a finishing [BackupWorker] to enqueue its single successor at
     * the latest committed [nextDueAtEpochMs] on the worker's own bound queue
     * without cancelling the currently running worker (P12-15, P12-17).
     */
    fun syncScheduleFromWorker(
        context: Context,
        workerToken: String,
        delayMs: Long,
        schedule: String?,
        nextDueAtEpochMs: Long?,
        requestedWorkName: String? = null,
        requestedDatabaseName: String? = null,
        requestedStorageNamespace: String? = null,
    ) {
        val binding = resolveBinding(
            context = context,
            ownerId = workerToken,
            requestedWorkName = requestedWorkName,
            requestedDatabaseName = requestedDatabaseName,
            requestedStorageNamespace = requestedStorageNamespace,
        )
        val workName = binding.uniqueWorkName
        scheduleMutex.withLock {
            val targetTag = buildTargetTag(schedule, nextDueAtEpochMs)
            val workManager = WorkManager.getInstance(context)
            val infos = workManager.getWorkInfosForUniqueWork(workName).get()
            val otherUnfinished = infos.filter {
                !it.state.isFinished && "worker-${it.id}" != workerToken
            }
            if (targetTag != null &&
                otherUnfinished.size == 1 &&
                otherUnfinished.single().tags.contains(targetTag)
            ) {
                return@withLock
            }
            for (info in otherUnfinished) {
                workManager.cancelWorkById(info.id)
            }
            val request = buildScheduledRequest(
                context = context,
                delayMs = delayMs,
                nextDueAtEpochMs = nextDueAtEpochMs,
                targetTag = targetTag,
                binding = binding,
            )
            workManager.enqueueUniqueWork(
                workName,
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                request,
            )
        }
    }

    /**
     * Called by a finishing [BackupWorker] when no schedule is configured so
     * any other pending work on its bound queue is cancelled without cancelling
     * the finishing worker.
     */
    fun cancelScheduleFromWorker(
        context: Context,
        workerToken: String,
        requestedWorkName: String? = null,
    ) {
        val workName = resolveWorkName(context, workerToken, requestedWorkName)
        scheduleMutex.withLock {
            val workManager = WorkManager.getInstance(context)
            val infos = workManager.getWorkInfosForUniqueWork(workName).get()
            for (info in infos) {
                if (!info.state.isFinished && "worker-${info.id}" != workerToken) {
                    workManager.cancelWorkById(info.id)
                }
            }
        }
    }

    fun cancelSchedule(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        val workName = resolveWorkName(context, ownerId, requestedWorkName)
        scheduleMutex.withLock {
            WorkManager.getInstance(context).cancelUniqueWork(workName)
        }
    }

    fun getScheduledWorkCount(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): Int {
        val workName = resolveWorkName(context, ownerId, requestedWorkName)
        val infos = WorkManager.getInstance(context)
            .getWorkInfosForUniqueWork(workName)
            .get()
        return infos.count { !it.state.isFinished }
    }

    fun registerWorker(
        token: String,
        binding: WorkerRequestBinding,
    ): CompletableDeferred<ListenableWorker.Result> {
        workerBindings[token] = binding
        val deferred = CompletableDeferred<ListenableWorker.Result>()
        pendingWorkers[token] = deferred
        return deferred
    }

    fun completeWorker(token: String, outcome: String) {
        val deferred = pendingWorkers.remove(token) ?: return
        val result = when (outcome) {
            "success" -> ListenableWorker.Result.success()
            "retry" -> ListenableWorker.Result.retry()
            else -> ListenableWorker.Result.failure()
        }
        deferred.complete(result)
    }

    fun unregisterWorker(token: String) {
        pendingWorkers.remove(token)
        workerBindings.remove(token)
    }

    // Debug-only test helpers. All callers must verify isDebuggable(context).

    fun enqueueImmediateWorkForTest(
        context: Context,
        ownerId: String,
        requireNetwork: Boolean,
        workerMode: String,
        schedule: String? = null,
        nextDueAtEpochMs: Long? = null,
        requestedWorkName: String? = null,
        requestedDatabaseName: String? = null,
        requestedStorageNamespace: String? = null,
    ): String {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val binding = resolveBinding(
            context = context,
            ownerId = ownerId,
            requestedWorkName = requestedWorkName,
            requestedDatabaseName = requestedDatabaseName,
            requestedStorageNamespace = requestedStorageNamespace,
        )
        val workName = binding.uniqueWorkName
        return scheduleMutex.withLock {
            val constraintsBuilder = Constraints.Builder()
            if (requireNetwork) {
                constraintsBuilder.setRequiredNetworkType(NetworkType.CONNECTED)
            }
            val targetTag = buildTargetTag(schedule, nextDueAtEpochMs)
            val builder = OneTimeWorkRequestBuilder<BackupWorker>()
                .setConstraints(constraintsBuilder.build())
                .setInputData(buildWorkerInputData(context, workerMode, binding))
                .addTag(WORK_TAG)
            if (!targetTag.isNullOrBlank()) {
                builder.addTag(targetTag)
            }
            val request = builder.build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                workName,
                ExistingWorkPolicy.REPLACE,
                request,
            )
            request.id.toString()
        }
    }

    fun getWorkStateForTest(context: Context, workId: String): String? {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val info: WorkInfo = WorkManager.getInstance(context)
            .getWorkInfoById(UUID.fromString(workId))
            .get() ?: return null
        return info.state.name
    }

    fun getUniqueWorkInfosForTest(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ): List<Map<String, Any?>> {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val workName = resolveWorkName(context, ownerId, requestedWorkName)
        return readWorkInfosForName(context, workName)
    }

    /**
     * Read-only inspection of the ordinary app's [UNIQUE_WORK_NAME] queue so
     * tests can verify that the ordinary installation's scheduled work ID was
     * never replaced or cancelled by the isolated test fixture (P12-17).
     */
    fun getProductionUniqueWorkInfosForTest(context: Context): List<Map<String, Any?>> {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        return readWorkInfosForName(context, UNIQUE_WORK_NAME)
    }

    private fun readWorkInfosForName(
        context: Context,
        workName: String,
    ): List<Map<String, Any?>> {
        val infos = WorkManager.getInstance(context)
            .getWorkInfosForUniqueWork(workName)
            .get()
        return infos.map { info ->
            mapOf(
                "id" to info.id.toString(),
                "state" to info.state.name,
                "nextScheduleTimeMillis" to info.nextScheduleTimeMillis,
                "tags" to info.tags.toList(),
            )
        }
    }

    private fun barrierScopeFor(scopeWorkName: String): TestBarrierScopeState =
        testBarrierScopes.getOrPut(scopeWorkName) { TestBarrierScopeState() }

    fun armTestCommitPause(
        context: Context,
        ownerId: String,
        stage: String,
        requestedWorkName: String? = null,
    ) {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        testBarrierMutex.withLock {
            val scope = barrierScopeFor(scopeName)
            scope.pausedLatch?.countDown()
            scope.releaseLatch?.countDown()
            scope.armedStage = stage
            scope.pausedLatch = CountDownLatch(1)
            scope.releaseLatch = CountDownLatch(1)
        }
    }

    fun awaitTestCommitRelease(
        context: Context,
        ownerId: String,
        stage: String,
        requestedWorkName: String? = null,
    ) {
        if (!isDebuggable(context)) return
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        val (paused, release) = testBarrierMutex.withLock {
            val scope = barrierScopeFor(scopeName)
            if (scope.armedStage != stage) return
            Pair(scope.pausedLatch, scope.releaseLatch)
        }
        paused?.countDown()
        release?.await(30, TimeUnit.SECONDS)
    }

    fun waitForTestCommitPause(
        context: Context,
        ownerId: String,
        timeoutMs: Long,
        requestedWorkName: String? = null,
    ): Boolean {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        val latch = testBarrierMutex.withLock {
            barrierScopeFor(scopeName).pausedLatch
        } ?: return false
        return latch.await(timeoutMs.coerceAtLeast(1L), TimeUnit.MILLISECONDS)
    }

    fun releaseTestCommitPause(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        check(isDebuggable(context)) { "Test hooks are only available in debug builds" }
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        testBarrierMutex.withLock {
            val scope = barrierScopeFor(scopeName)
            scope.armedStage = null
            scope.releaseLatch?.countDown()
        }
    }

    fun clearTestHooks(
        context: Context,
        ownerId: String,
        requestedWorkName: String? = null,
    ) {
        if (!isDebuggable(context)) return
        val scopeName = resolveWorkName(context, ownerId, requestedWorkName)
        testBarrierMutex.withLock {
            val scope = testBarrierScopes.remove(scopeName)
            scope?.armedStage = null
            scope?.pausedLatch?.countDown()
            scope?.releaseLatch?.countDown()
        }
        if (scopeName != UNIQUE_WORK_NAME) {
            scheduleMutex.withLock {
                WorkManager.getInstance(context).cancelUniqueWork(scopeName)
            }
        }
    }
}
