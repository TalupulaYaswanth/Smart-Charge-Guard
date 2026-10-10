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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (batteryMethodChannel != null) {
            batteryMethodChannel = null
        }
        super.onDestroy()
    }
}
