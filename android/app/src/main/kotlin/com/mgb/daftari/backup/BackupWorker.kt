package com.mgb.daftari.backup

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.util.concurrent.TimeUnit

/**
 * Android WorkManager worker that boots a headless [FlutterEngine] running
 * `backupWorkerMain` in
 * `package:daftariapp/features/backup/data/services/backup_background_worker.dart`,
 * executing the shared backup pipeline even when Daftari is closed.
 *
 * Database name, secure storage namespace and unique WorkManager queue name are
 * bound strictly to each [WorkRequest]'s [inputData] so an ordinary job with no
 * fixture keys never falls back to a test database, namespace or queue.
 */
class BackupWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    companion object {
        private const val DART_ENTRYPOINT_LIBRARY =
            "package:daftariapp/features/backup/data/services/backup_background_worker.dart"
        private const val DART_ENTRYPOINT_NAME = "backupWorkerMain"
        private val WORKER_TIMEOUT_MS = TimeUnit.MINUTES.toMillis(9)
    }

    override suspend fun doWork(): Result {
        val workerToken = "worker-$id"
        val isDebug = BackupCoordinator.isDebuggable(applicationContext)
        val requestedMode = inputData.getString(BackupCoordinator.INPUT_WORKER_MODE)
        val workerMode =
            if (!requestedMode.isNullOrBlank() && isDebug) {
                requestedMode
            } else {
                BackupCoordinator.MODE_PRODUCTION
            }
        val testDbName = if (isDebug) {
            inputData.getString(BackupCoordinator.INPUT_TEST_DB_NAME)?.trim().orEmpty()
        } else {
            ""
        }
        val testStorageNs = if (isDebug) {
            inputData.getString(BackupCoordinator.INPUT_TEST_STORAGE_NAMESPACE)?.trim().orEmpty()
        } else {
            ""
        }
        val boundWorkName = if (isDebug) {
            inputData.getString(BackupCoordinator.INPUT_UNIQUE_WORK_NAME)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: BackupCoordinator.UNIQUE_WORK_NAME
        } else {
            BackupCoordinator.UNIQUE_WORK_NAME
        }

        val binding = BackupCoordinator.WorkerRequestBinding(
            uniqueWorkName = boundWorkName,
            databaseName = testDbName.takeIf { it.isNotEmpty() },
            storageNamespace = testStorageNs.takeIf { it.isNotEmpty() },
        )
        val completion = BackupCoordinator.registerWorker(workerToken, binding)
        var engine: FlutterEngine? = null
        var channelHandler: BackupChannelHandler? = null

        return try {
            withContext(Dispatchers.Main) {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)

                val appBundlePath = loader.findAppBundlePath()
                val flutterEngine = FlutterEngine(applicationContext)
                engine = flutterEngine
                channelHandler = BackupChannelHandler.attach(
                    context = applicationContext,
                    messenger = flutterEngine.dartExecutor.binaryMessenger,
                    ownerId = workerToken,
                    isForeground = false,
                )

                val entrypoint = DartExecutor.DartEntrypoint(
                    appBundlePath,
                    DART_ENTRYPOINT_LIBRARY,
                    DART_ENTRYPOINT_NAME,
                )
                val dartArgs = if (
                    isDebug &&
                    (testDbName.isNotEmpty() ||
                        testStorageNs.isNotEmpty() ||
                        boundWorkName != BackupCoordinator.UNIQUE_WORK_NAME)
                ) {
                    listOf(workerToken, workerMode, testDbName, testStorageNs, boundWorkName)
                } else {
                    listOf(workerToken, workerMode)
                }
                flutterEngine.dartExecutor.executeDartEntrypoint(
                    entrypoint,
                    dartArgs,
                )
            }

            withTimeoutOrNull(WORKER_TIMEOUT_MS) { completion.await() }
                ?: Result.retry()
        } catch (_: Exception) {
            Result.retry()
        } finally {
            withContext(NonCancellable) {
                BackupCoordinator.unregisterWorker(workerToken)
                BackupCoordinator.releaseAllForOwner(applicationContext, workerToken)
                withContext(Dispatchers.Main) {
                    channelHandler?.detach()
                    engine?.destroy()
                }
                BackupCoordinator.notifyForegroundStateChanged()
            }
        }
    }
}
