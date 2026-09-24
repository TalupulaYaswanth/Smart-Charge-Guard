package com.chargealarm.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "com.chargealarm.app/apk_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "getApkPath") {
                val apkPath = context.applicationInfo.sourceDir
                result.success(apkPath)
            } else {
                result.notImplemented()
            }
        }
    }
}
