package com.chargealarm.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent

class BatteryMonitoringService : Service() {

    companion object {
        const val TAG = "BatteryMonitorService"
        const val ACTION_START_MONITORING = "com.chargealarm.app.ACTION_START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.chargealarm.app.ACTION_STOP_MONITORING"
        const val ACTION_TEST_ALARM = "com.chargealarm.app.ACTION_TEST_ALARM"
        const val ACTION_STOP_ALARM = "com.chargealarm.app.ACTION_STOP_ALARM"
        const val ACTION_UPDATE_CONFIG = "com.chargealarm.app.ACTION_UPDATE_CONFIG"

        const val NOTIFICATION_MONITOR_ID = 1001
        const val NOTIFICATION_ALARM_ID = 8080
        const val CHANNEL_MONITOR = "charge_monitor_channel"
        const val CHANNEL_ALARM = "charge_alarm_alert_channel"

        private var isServiceRunning = false
        private var isAlarmActive = false
        private var lastBatteryLevel = 0
        private var lastIsCharging = false

        fun startMonitoring(context: Context, targetLevel: Int, platform: String, uri: String) {
            val intent = Intent(context, BatteryMonitoringService::class.java).apply {
                action = ACTION_START_MONITORING
                putExtra("targetLevel", targetLevel)
                putExtra("musicPlatform", platform)
                putExtra("musicUri", uri)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopMonitoring(context: Context) {
            val intent = Intent(context, BatteryMonitoringService::class.java).apply {
                action = ACTION_STOP_MONITORING
            }
            context.startService(intent)
        }

        fun testAlarm(context: Context, platform: String, uri: String) {
            val intent = Intent(context, BatteryMonitoringService::class.java).apply {
                action = ACTION_TEST_ALARM
                putExtra("musicPlatform", platform)
                putExtra("musicUri", uri)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopAlarm(context: Context) {
            val intent = Intent(context, BatteryMonitoringService::class.java).apply {
                action = ACTION_STOP_ALARM
            }
            context.startService(intent)
        }

        fun getStatus(context: Context): Map<String, Any> {
            return mapOf(
                "isMonitoring" to isServiceRunning,
                "isAlarmFiring" to isAlarmActive,
                "batteryLevel" to lastBatteryLevel,
                "isCharging" to lastIsCharging
            )
        }

        fun launchMusicApp(context: Context, platform: String, uri: String): Boolean {
            return try {
                val intent = createPlatformLaunchIntent(context, platform, uri)
                if (intent != null) {
                    context.startActivity(intent)
                    sendMediaPlayBroadcast(context, getPackageForPlatform(platform))
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch music app: ${e.message}")
                false
            }
        }

        fun getPackageForPlatform(platform: String): String? {
            return when {
                platform.contains("Spotify", ignoreCase = true) -> "com.spotify.music"
                platform.contains("JioSaavn", ignoreCase = true) -> "com.jiosaavn.android"
                platform.contains("YouTube Music", ignoreCase = true) -> "com.google.android.apps.youtube.music"
                platform.contains("YouTube", ignoreCase = true) -> "com.google.android.youtube"
                else -> null
            }
        }

        fun normalizeSpotifyUri(input: String): String {
            val trimmed = input.trim()
            if (trimmed.isEmpty()) return "spotify:search:wake%20up"
            if (trimmed.startsWith("spotify:")) return trimmed
            val trackMatch = Regex("""open\.spotify\.com/track/([a-zA-Z0-9]+)""").find(trimmed)
            if (trackMatch != null) return "spotify:track:${trackMatch.groupValues[1]}"
            val playlistMatch = Regex("""open\.spotify\.com/playlist/([a-zA-Z0-9]+)""").find(trimmed)
            if (playlistMatch != null) return "spotify:playlist:${playlistMatch.groupValues[1]}"
            val albumMatch = Regex("""open\.spotify\.com/album/([a-zA-Z0-9]+)""").find(trimmed)
            if (albumMatch != null) return "spotify:album:${albumMatch.groupValues[1]}"
            if (!trimmed.startsWith("http")) {
                return "spotify:search:${Uri.encode(trimmed)}"
            }
            return trimmed
        }

        fun createPlatformLaunchIntent(context: Context, platform: String, uriString: String): Intent? {
            val pm = context.packageManager
            val trimmed = uriString.trim()

            // Security: Strictly disallow dangerous file / content / script URI schemes
            if (trimmed.startsWith("file:", ignoreCase = true) ||
                trimmed.startsWith("content:", ignoreCase = true) ||
                trimmed.startsWith("javascript:", ignoreCase = true) ||
                trimmed.startsWith("data:", ignoreCase = true)) {
                Log.w(TAG, "Rejected potentially dangerous URI scheme: $trimmed")
                return null
            }

            if (platform.contains("Spotify", ignoreCase = true)) {
                val spotifyTarget = normalizeSpotifyUri(trimmed)
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(spotifyTarget)).apply {
                    setPackage("com.spotify.music")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                if (intent.resolveActivity(pm) != null) return intent

                val fallback = pm.getLaunchIntentForPackage("com.spotify.music")
                if (fallback != null) {
                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    return fallback
                }

                return Intent(Intent.ACTION_VIEW, Uri.parse(if (trimmed.startsWith("http")) trimmed else "https://open.spotify.com")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }

            if (platform.contains("JioSaavn", ignoreCase = true)) {
                val target = if (trimmed.isNotEmpty()) {
                    if (trimmed.startsWith("http") || trimmed.startsWith("jiosaavn:")) trimmed
                    else "jiosaavn://search/${Uri.encode(trimmed)}"
                } else {
                    "jiosaavn://"
                }

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    setPackage("com.jiosaavn.android")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                if (intent.resolveActivity(pm) != null) return intent

                val fallback = pm.getLaunchIntentForPackage("com.jiosaavn.android")
                if (fallback != null) {
                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    return fallback
                }

                return Intent(Intent.ACTION_VIEW, Uri.parse(if (trimmed.startsWith("http")) trimmed else "https://www.jiosaavn.com")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }

            if (platform.contains("YouTube Music", ignoreCase = true)) {
                val target = if (trimmed.isNotEmpty()) {
                    if (trimmed.startsWith("http")) trimmed
                    else "https://music.youtube.com/search?q=${Uri.encode(trimmed)}"
                } else {
                    "https://music.youtube.com"
                }

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    setPackage("com.google.android.apps.youtube.music")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                if (intent.resolveActivity(pm) != null) return intent

                val fallback = pm.getLaunchIntentForPackage("com.google.android.apps.youtube.music")
                if (fallback != null) {
                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    return fallback
                }

                return Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }

            if (platform.contains("YouTube", ignoreCase = true)) {
                val target = if (trimmed.isNotEmpty()) {
                    if (trimmed.startsWith("http") || trimmed.startsWith("vnd.youtube")) trimmed
                    else "https://www.youtube.com/results?search_query=${Uri.encode(trimmed)}"
                } else {
                    "https://www.youtube.com"
                }
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    setPackage("com.google.android.youtube")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                if (intent.resolveActivity(pm) != null) return intent

                return Intent(Intent.ACTION_VIEW, Uri.parse(target)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }

            return null
        }

        fun sendMediaPlayBroadcast(context: Context, targetPackage: String?) {
            try {
                val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY))
                    if (!targetPackage.isNullOrBlank()) {
                        setPackage(targetPackage)
                    }
                }
                context.sendOrderedBroadcast(downIntent, null)

                val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY))
                    if (!targetPackage.isNullOrBlank()) {
                        setPackage(targetPackage)
                    }
                }
                context.sendOrderedBroadcast(upIntent, null)
            } catch (e: Exception) {
                Log.w(TAG, "Media play broadcast error: ${e.message}")
            }
        }

        fun sendMediaPauseBroadcast(context: Context) {
            try {
                val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
                }
                context.sendOrderedBroadcast(downIntent, null)

                val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                    putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
                }
                context.sendOrderedBroadcast(upIntent, null)
            } catch (_: Exception) {}
        }
    }

    private var monitorWakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isReceiverRegistered = false

    private var targetLevel: Int = 80
    private var musicPlatform: String = "Spotify"
    private var musicUri: String = ""
    private var currentLevel: Int = 0
    private var isCharging: Boolean = false
    private var hasFiredThisCycle: Boolean = false
    private var isAlarmFiring: Boolean = false

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            when (intent.action) {
                Intent.ACTION_BATTERY_CHANGED -> {
                    handleBatteryIntent(intent)
                }
                Intent.ACTION_POWER_DISCONNECTED -> {
                    isCharging = false
                    lastIsCharging = false
                    MainActivity.notifyBatteryUpdate(currentLevel, false)
                    // If user unplugs phone while alarm is firing, stop alarm automatically
                    if (isAlarmFiring) {
                        dismissAlarm()
                    }
                    hasFiredThisCycle = false
                    updateMonitorNotification(currentLevel, false)
                }
                Intent.ACTION_POWER_CONNECTED -> {
                    isCharging = true
                    lastIsCharging = true
                    MainActivity.notifyBatteryUpdate(currentLevel, true)
                    updateMonitorNotification(currentLevel, true)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        acquireMonitorWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START_MONITORING

        when (action) {
            ACTION_START_MONITORING, ACTION_UPDATE_CONFIG -> {
                targetLevel = intent?.getIntExtra("targetLevel", targetLevel) ?: targetLevel
                musicPlatform = intent?.getStringExtra("musicPlatform") ?: musicPlatform
                musicUri = intent?.getStringExtra("musicUri") ?: musicUri

                isServiceRunning = true
                startServiceForeground()
                registerBatteryReceiver()

                // Read immediate battery status
                val initialBattery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                if (initialBattery != null) {
                    handleBatteryIntent(initialBattery)
                }
            }
            ACTION_STOP_MONITORING -> {
                dismissAlarm()
                stopServiceForeground()
                stopSelf()
            }
            ACTION_TEST_ALARM -> {
                musicPlatform = intent?.getStringExtra("musicPlatform") ?: musicPlatform
                musicUri = intent?.getStringExtra("musicUri") ?: musicUri
                triggerAlarmExecution()
            }
            ACTION_STOP_ALARM -> {
                dismissAlarm()
            }
        }

        return START_STICKY
    }

    private fun startServiceForeground() {
        val notification = buildMonitorNotification(currentLevel, isCharging)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_MONITOR_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_MONITOR_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Foreground start failed: ${e.message}")
            try {
                startForeground(NOTIFICATION_MONITOR_ID, notification)
            } catch (_: Exception) {}
        }
    }

    private fun stopServiceForeground() {
        isServiceRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun registerBatteryReceiver() {
        if (!isReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_BATTERY_CHANGED)
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
            }
            registerReceiver(batteryReceiver, filter)
            isReceiverRegistered = true
        }
    }

    private fun handleBatteryIntent(intent: Intent) {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level >= 0 && scale > 0) {
            currentLevel = (level * 100) / scale
            lastBatteryLevel = currentLevel
        }

        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
        val charging = (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL ||
                        plugged > 0)

        isCharging = charging
        lastIsCharging = charging

        // Notify Flutter UI if listening
        MainActivity.notifyBatteryUpdate(currentLevel, isCharging)

        // If unplugged, stop alarm if active and reset debounce
        if (!isCharging) {
            if (isAlarmFiring) {
                dismissAlarm()
            }
            hasFiredThisCycle = false
            updateMonitorNotification(currentLevel, false)
            return
        }

        // If charging but below target, reset debounce
        if (currentLevel < targetLevel) {
            hasFiredThisCycle = false
        }

        // Update ongoing foreground notification
        updateMonitorNotification(currentLevel, true)

        // Check trigger condition:
        // Charging + Level >= Target + Not yet fired in this cycle + Not currently firing
        if (isCharging && currentLevel >= targetLevel && !hasFiredThisCycle && !isAlarmFiring) {
            hasFiredThisCycle = true
            triggerAlarmExecution()
        }
    }

    private fun triggerAlarmExecution() {
        isAlarmFiring = true
        isAlarmActive = true

        // 1. Wake device screen up from sleep mode
        wakeScreenUp()

        // 2. Start repeating pulsing vibration
        startVibrating()

        // 3. Play alarm audio / song loud on ALARM audio stream (audible safety backup)
        startAlarmAudio(musicPlatform, musicUri)

        // 4. Launch target music platform app (Spotify, JioSaavn, YouTube Music, etc.)
        launchMusicApp(this, musicPlatform, musicUri)

        // 5. Show high-priority heads-up & full-screen notification
        showAlarmNotification()

        // 6. Notify Flutter UI
        MainActivity.notifyAlarmTriggered(currentLevel)
    }

    private fun dismissAlarm() {
        isAlarmFiring = false
        isAlarmActive = false

        stopAlarmAudio()
        stopVibrating()
        sendMediaPauseBroadcast(this)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ALARM_ID)

        // Refresh monitor notification
        updateMonitorNotification(currentLevel, isCharging)

        // Notify Flutter UI
        MainActivity.notifyAlarmStopped()
    }

    @Suppress("DEPRECATION")
    private fun wakeScreenUp() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val screenWakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "ChargeAlarm:AlarmScreenWakeLock"
            )
            screenWakeLock.acquire(20000) // 20 seconds wake lock
        } catch (e: Exception) {
            Log.e(TAG, "Screen wake error: ${e.message}")
        }
    }

    private fun acquireMonitorWakeLock() {
        try {
            if (monitorWakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                monitorWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "ChargeAlarm:MonitorWakeLock"
                )
                monitorWakeLock?.acquire()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Monitor wake lock error: ${e.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun startVibrating() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibrator = vm?.defaultVibrator
            } else {
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 800, 500, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vibration error: ${e.message}")
        }
    }

    private fun stopVibrating() {
        try {
            vibrator?.cancel()
        } catch (_: Exception) {}
    }

    private fun startAlarmAudio(platform: String, uriString: String) {
        stopAlarmAudio()
        try {
            val player = MediaPlayer().apply {
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
            }

            var streamingUrl = false
            val isCustomStream = uriString.isNotBlank() &&
                    (uriString.startsWith("http://") || uriString.startsWith("https://")) &&
                    !uriString.contains("open.spotify.com") &&
                    !uriString.contains("jiosaavn.com") &&
                    !uriString.contains("youtube.com") &&
                    !uriString.contains("youtu.be")

            if (isCustomStream) {
                try {
                    player.setDataSource(applicationContext, Uri.parse(uriString.trim()))
                    player.setOnPreparedListener { mp ->
                        mp.start()
                        Log.d(TAG, "Audio stream started successfully: $uriString")
                    }
                    player.setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "MediaPlayer stream error what=$what extra=$extra. Falling back to system alarm.")
                        playSystemAlarmFallback()
                        true
                    }
                    player.prepareAsync()
                    streamingUrl = true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stream custom URL: ${e.message}")
                    streamingUrl = false
                }
            }

            if (!streamingUrl) {
                playSystemAlarm(player)
            }

            mediaPlayer = player
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start alarm audio: ${e.message}")
            playSystemAlarmFallback()
        }
    }

    private fun playSystemAlarm(player: MediaPlayer) {
        try {
            var alarmUri: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            if (alarmUri == null) {
                alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }

            if (alarmUri != null) {
                player.setDataSource(applicationContext, alarmUri)
                player.prepare()
                player.start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play default system alarm: ${e.message}")
        }
    }

    private fun playSystemAlarmFallback() {
        try {
            mediaPlayer?.release()
            val player = MediaPlayer().apply {
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
            }
            playSystemAlarm(player)
            mediaPlayer = player
        } catch (e: Exception) {
            Log.e(TAG, "System alarm fallback failed: ${e.message}")
        }
    }

    private fun stopAlarmAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null
        } catch (_: Exception) {
            mediaPlayer = null
        }
    }

    private fun showAlarmNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Full-screen Intent (brings MainActivity over lockscreen)
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("alarmTriggered", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(this, 8081, fullScreenIntent, pendingFlags)

        // STOP Action Intent
        val stopIntent = Intent(this, AlarmActionReceiver::class.java).apply {
            action = ACTION_STOP_ALARM
        }
        val stopPendingIntent = PendingIntent.getBroadcast(this, 8082, stopIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ALARM)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        }

        builder.setContentTitle("⚡ Battery Reached $currentLevel%!")
            .setContentText("Unplug your charger to protect battery health!")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_ALARM)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP ALARM", stopPendingIntent)

        // Add direct app launch action if Spotify, JioSaavn, YouTube Music, or other platforms
        val platformLaunchIntent = createPlatformLaunchIntent(this, musicPlatform, musicUri)
        if (platformLaunchIntent != null) {
            val platformPending = PendingIntent.getActivity(this, 8083, platformLaunchIntent, pendingFlags)
            val actionTitle = when {
                musicPlatform.contains("Spotify", ignoreCase = true) -> "OPEN SPOTIFY"
                musicPlatform.contains("JioSaavn", ignoreCase = true) -> "OPEN JIOSAAVN"
                musicPlatform.contains("YouTube Music", ignoreCase = true) -> "OPEN YT MUSIC"
                musicPlatform.contains("YouTube", ignoreCase = true) -> "OPEN YOUTUBE"
                else -> "OPEN MUSIC"
            }
            builder.addAction(android.R.drawable.ic_media_play, actionTitle, platformPending)
        }

        notificationManager.notify(NOTIFICATION_ALARM_ID, builder.build())
    }

    private fun updateMonitorNotification(level: Int, charging: Boolean) {
        if (!isServiceRunning || isAlarmFiring) return
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_MONITOR_ID, buildMonitorNotification(level, charging))
    }

    private fun buildMonitorNotification(level: Int, charging: Boolean): Notification {
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(this, 1001, openAppIntent, pendingFlags)

        val title = if (charging) {
            "⚡ ChargeAlarm Active (Battery: $level%)"
        } else {
            "⚡ ChargeAlarm Idle (Unplugged)"
        }

        val text = if (charging) {
            "Monitoring charging. Alarm set for $targetLevel%."
        } else {
            "Plug in charger to monitor for $targetLevel% protection."
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_MONITOR)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        return builder.setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Monitor Channel (Silent background notification)
            val monitorChannel = NotificationChannel(
                CHANNEL_MONITOR,
                "Battery Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors battery level and charging state continuously in sleep mode"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(monitorChannel)

            // Alarm Channel (High-priority alert, sound, vibration)
            val alarmChannel = NotificationChannel(
                CHANNEL_ALARM,
                "Battery 80% Alarm Alert",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent alarm notification when charging hits target threshold"
                enableVibration(true)
                enableLights(true)
                lightColor = Color.GREEN
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(alarmChannel)
        }
    }

    override fun onDestroy() {
        isServiceRunning = false
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(batteryReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
        stopAlarmAudio()
        stopVibrating()
        try {
            monitorWakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            monitorWakeLock = null
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
