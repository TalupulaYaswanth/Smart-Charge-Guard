package com.chargealarm.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            BatteryMonitoringService.ACTION_STOP_ALARM -> {
                BatteryMonitoringService.stopAlarm(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val enabled = prefs.getBoolean("flutter.alarm_protection_enabled", true)
                if (enabled) {
                    val targetLevel = prefs.getLong("flutter.target_percentage", 80L).toInt()
                    val musicPlatform = prefs.getString("flutter.music_platform", "Spotify") ?: "Spotify"
                    val musicUri = prefs.getString("flutter.music_uri", "") ?: ""
                    BatteryMonitoringService.startMonitoring(context, targetLevel, musicPlatform, musicUri)
                }
            }
        }
    }
}
