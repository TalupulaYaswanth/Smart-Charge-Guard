package com.chargealarm.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        const val CHANNEL_APK_SHARE = "com.chargealarm.app/apk_share"
        const val CHANNEL_BATTERY_ALARM = "com.chargealarm.app/battery_alarm"
        var batteryMethodChannel: MethodChannel? = null

        fun notifyBatteryUpdate(level: Int, isCharging: Boolean) {
            batteryMethodChannel?.invokeMethod(
                "onBatteryUpdate",
                mapOf("level" to level, "isCharging" to isCharging)
            )
        }

        fun notifyAlarmTriggered(level: Int) {
            batteryMethodChannel?.invokeMethod(
                "onAlarmTriggered",
                mapOf("level" to level)
            )
        }

        fun notifyAlarmStopped() {
            batteryMethodChannel?.invokeMethod("onAlarmStopped", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenFlags()
    }

    override fun onResume() {
        super.onResume()
        configureLockScreenFlags()
    }

    private fun configureLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // WhatsApp / System APK sharing channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_APK_SHARE).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "getApkPath") {
                val apkPath = applicationContext.applicationInfo.sourceDir
                result.success(apkPath)
            } else {
                result.notImplemented()
            }
        }

        // Native Battery Foreground Service & Alarm Audio channel
        val alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BATTERY_ALARM)
        batteryMethodChannel = alarmChannel

        alarmChannel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startMonitoring" -> {
                    val targetLevel = (call.argument<Number>("targetLevel"))?.toInt() ?: 80
                    val musicPlatform = call.argument<String>("musicPlatform") ?: "Spotify"
                    val musicUri = call.argument<String>("musicUri") ?: ""
                    BatteryMonitoringService.startMonitoring(this, targetLevel, musicPlatform, musicUri)
                    result.success(true)
                }
                "stopMonitoring" -> {
                    BatteryMonitoringService.stopMonitoring(this)
                    result.success(true)
                }
                "testAlarm" -> {
                    val musicPlatform = call.argument<String>("musicPlatform") ?: "Spotify"
                    val musicUri = call.argument<String>("musicUri") ?: ""
                    BatteryMonitoringService.testAlarm(this, musicPlatform, musicUri)
                    result.success(true)
                }
                "stopAlarm" -> {
                    BatteryMonitoringService.stopAlarm(this)
                    result.success(true)
                }
                "getStatus" -> {
                    val status = BatteryMonitoringService.getStatus(this)
                    result.success(status)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                    if (!isIgnoring) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(intent)
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(isIgnoring)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "isAppInstalled" -> {
                    val targetPackage = call.argument<String>("packageName") ?: ""
                    result.success(isPackageInstalled(targetPackage))
                }
                "openAppOrUri" -> {
                    val platform = call.argument<String>("platform") ?: "Spotify"
                    val uri = call.argument<String>("uri") ?: ""
                    val launched = BatteryMonitoringService.launchMusicApp(this, platform, uri)
                    result.success(launched)
                }
                "getSecurityStatus" -> {
                    val isRooted = checkDeviceRoot()
                    val isDebugger = checkDebuggerAttached()
                    val isEmulator = checkIsEmulator()
                    result.success(
                        mapOf(
                            "isRooted" to isRooted,
                            "isDebugger" to isDebugger,
                            "isEmulator" to isEmulator,
                            "isSecure" to (!isRooted && !isDebugger)
                        )
                    )
                }
                "setScreenSecure" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkDeviceRoot(): Boolean {
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in rootPaths) {
            try {
                if (java.io.File(path).exists()) return true
            } catch (_: Exception) {}
        }
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }
        return false
    }

    private fun checkDebuggerAttached(): Boolean {
        return android.os.Debug.isDebuggerConnected() || android.os.Debug.waitingForDebugger()
    }

    private fun checkIsEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || "google_sdk" == Build.PRODUCT)
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        if (batteryMethodChannel != null) {
            batteryMethodChannel = null
        }
        super.onDestroy()
    }
}
