package com.mgb.daftari.backup

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * MethodChannel bridge connecting each Dart isolate (foreground UI or
 * background [BackupWorker]) to the process-wide [BackupCoordinator].
 */
class BackupChannelHandler private constructor(
    private val context: Context,
    private val channel: MethodChannel,
    private val ownerId: String,
    private val isForeground: Boolean,
) : MethodChannel.MethodCallHandler {

    companion object {
        private val mainHandler = Handler(Looper.getMainLooper())
        private val workerExecutor = Executors.newCachedThreadPool()

        fun attach(
            context: Context,
            messenger: BinaryMessenger,
            ownerId: String,
            isForeground: Boolean,
        ): BackupChannelHandler {
            val channel = MethodChannel(messenger, BackupCoordinator.CHANNEL_NAME)
            val handler = BackupChannelHandler(
                context = context.applicationContext,
                channel = channel,
                ownerId = ownerId,
                isForeground = isForeground,
            )
            channel.setMethodCallHandler(handler)
            if (isForeground) {
                BackupCoordinator.registerForegroundHandler(handler)
            }
            return handler
        }
    }

    @Volatile
    private var detached = false

    fun notifyBackupStateChanged() {
        if (detached) return
        mainHandler.post {
            if (!detached) {
                try {
                    channel.invokeMethod("onBackupStateChanged", null)
                } catch (_: Exception) {
                }
            }
        }
    }

    fun detach() {
        detached = true
        if (isForeground) {
            BackupCoordinator.unregisterForegroundHandler(this)
        }
        channel.setMethodCallHandler(null)
        BackupCoordinator.releaseAllForOwner(context, ownerId)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val uniqueWorkName = call.argument<String>("uniqueWorkName")
        val databaseName = call.argument<String>("databaseName")
        val storageNamespace = call.argument<String>("storageNamespace")

        when (call.method) {
            "syncSchedule" -> {
                val delayMs = (call.argument<Number>("delayMs") ?: 0L).toLong()
                val schedule = call.argument<String>("schedule")
                val nextDueAtEpochMs = call.argument<Number>("nextDueAtEpochMs")?.toLong()
                runAsync(result) {
                    BackupCoordinator.syncSchedule(
                        context = context,
                        ownerId = ownerId,
                        delayMs = delayMs,
                        schedule = schedule,
                        nextDueAtEpochMs = nextDueAtEpochMs,
                        requestedWorkName = uniqueWorkName,
                        requestedDatabaseName = databaseName,
                        requestedStorageNamespace = storageNamespace,
                    )
                    null
                }
            }

            "syncScheduleFromWorker" -> {
                val token = call.argument<String>("token") ?: ownerId
                val delayMs = (call.argument<Number>("delayMs") ?: 0L).toLong()
                val schedule = call.argument<String>("schedule")
                val nextDueAtEpochMs = call.argument<Number>("nextDueAtEpochMs")?.toLong()
                runAsync(result) {
                    BackupCoordinator.syncScheduleFromWorker(
                        context = context,
                        workerToken = token,
                        delayMs = delayMs,
                        schedule = schedule,
                        nextDueAtEpochMs = nextDueAtEpochMs,
                        requestedWorkName = uniqueWorkName,
                        requestedDatabaseName = databaseName,
                        requestedStorageNamespace = storageNamespace,
                    )
                    null
                }
            }

            "cancelScheduleFromWorker" -> {
                val token = call.argument<String>("token") ?: ownerId
                runAsync(result) {
                    BackupCoordinator.cancelScheduleFromWorker(
                        context = context,
                        workerToken = token,
                        requestedWorkName = uniqueWorkName,
                    )
                    null
                }
            }

            "cancelSchedule" -> {
                runAsync(result) {
                    BackupCoordinator.cancelSchedule(
                        context = context,
                        ownerId = ownerId,
                        requestedWorkName = uniqueWorkName,
                    )
                    null
                }
            }

            "getScheduledWorkCount" -> runAsync(result) {
                BackupCoordinator.getScheduledWorkCount(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
            }

            "tryAcquireRunLock" -> {
                result.success(
                    BackupCoordinator.tryAcquireRunLock(
                        context = context,
                        ownerId = ownerId,
                        requestedWorkName = uniqueWorkName,
                    ),
                )
            }

            "releaseRunLock" -> {
                BackupCoordinator.releaseRunLock(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            "isRunLocked" -> {
                result.success(
                    BackupCoordinator.isRunLocked(
                        context = context,
                        ownerId = ownerId,
                        requestedWorkName = uniqueWorkName,
                    ),
                )
            }

            "readSessionEpoch" -> {
                result.success(
                    BackupCoordinator.readSessionEpoch(
                        context = context,
                        ownerId = ownerId,
                        requestedWorkName = uniqueWorkName,
                    ),
                )
            }

            "tryEnterCommit" -> {
                val expectedEpoch = (call.argument<Number>("expectedEpoch") ?: 0).toInt()
                result.success(
                    BackupCoordinator.tryEnterCommit(
                        context = context,
                        ownerId = ownerId,
                        expectedEpoch = expectedEpoch,
                        requestedWorkName = uniqueWorkName,
                    ),
                )
            }

            "exitCommit" -> {
                BackupCoordinator.exitCommit(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            "beginSessionInvalidation" -> runAsync(result) {
                BackupCoordinator.beginSessionInvalidation(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                null
            }

            "endSessionInvalidation" -> {
                BackupCoordinator.endSessionInvalidation(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            "notifyBackupStateChanged" -> {
                BackupCoordinator.notifyForegroundStateChanged()
                result.success(null)
            }

            "completeWorker" -> {
                val token = call.argument<String>("token") ?: ownerId
                val outcome = call.argument<String>("outcome") ?: "failure"
                BackupCoordinator.completeWorker(token, outcome)
                result.success(null)
            }

            "configureTestEnvironment" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                result.success(null)
            }

            "enqueueImmediateWorkForTest" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                val requireNetwork = call.argument<Boolean>("requireNetwork") ?: false
                val workerMode = call.argument<String>("workerMode")
                    ?: BackupCoordinator.MODE_PRODUCTION
                val schedule = call.argument<String>("schedule")
                val nextDueAtEpochMs = call.argument<Number>("nextDueAtEpochMs")?.toLong()
                runAsync(result) {
                    BackupCoordinator.enqueueImmediateWorkForTest(
                        context = context,
                        ownerId = ownerId,
                        requireNetwork = requireNetwork,
                        workerMode = workerMode,
                        schedule = schedule,
                        nextDueAtEpochMs = nextDueAtEpochMs,
                        requestedWorkName = uniqueWorkName,
                        requestedDatabaseName = databaseName,
                        requestedStorageNamespace = storageNamespace,
                    )
                }
            }

            "getWorkStateForTest" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                val workId = call.argument<String>("workId")
                if (workId.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "workId is required", null)
                    return
                }
                runAsync(result) {
                    BackupCoordinator.getWorkStateForTest(context, workId)
                }
            }

            "getUniqueWorkInfosForTest" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                runAsync(result) {
                    BackupCoordinator.getUniqueWorkInfosForTest(
                        context = context,
                        ownerId = ownerId,
                        requestedWorkName = uniqueWorkName,
                    )
                }
            }

            "getProductionUniqueWorkInfosForTest" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                runAsync(result) {
                    BackupCoordinator.getProductionUniqueWorkInfosForTest(context)
                }
            }

            "armTestCommitPause" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                val stage = call.argument<String>("stage") ?: ""
                BackupCoordinator.armTestCommitPause(
                    context = context,
                    ownerId = ownerId,
                    stage = stage,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            "waitForTestCommitPause" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                val timeoutMs = (call.argument<Number>("timeoutMs") ?: 15000L).toLong()
                runAsync(result) {
                    BackupCoordinator.waitForTestCommitPause(
                        context = context,
                        ownerId = ownerId,
                        timeoutMs = timeoutMs,
                        requestedWorkName = uniqueWorkName,
                    )
                }
            }

            "awaitTestCommitRelease" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.success(null)
                    return
                }
                val stage = call.argument<String>("stage") ?: ""
                runAsync(result) {
                    BackupCoordinator.awaitTestCommitRelease(
                        context = context,
                        ownerId = ownerId,
                        stage = stage,
                        requestedWorkName = uniqueWorkName,
                    )
                    null
                }
            }

            "releaseTestCommitPause" -> {
                if (!BackupCoordinator.isDebuggable(context)) {
                    result.error("FORBIDDEN", "Test hooks require a debug build", null)
                    return
                }
                BackupCoordinator.releaseTestCommitPause(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            "clearTestHooks" -> {
                BackupCoordinator.clearTestHooks(
                    context = context,
                    ownerId = ownerId,
                    requestedWorkName = uniqueWorkName,
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        workerExecutor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("BACKUP_COORDINATOR_ERROR", error.message, null)
                }
            }
        }
    }
}
