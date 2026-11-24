package com.mgb.daftari

import com.mgb.daftari.backup.BackupChannelHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private var backupChannelHandler: BackupChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupChannelHandler?.detach()
        backupChannelHandler = BackupChannelHandler.attach(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            ownerId = "foreground-${System.identityHashCode(flutterEngine)}",
            isForeground = true,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        backupChannelHandler?.detach()
        backupChannelHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
