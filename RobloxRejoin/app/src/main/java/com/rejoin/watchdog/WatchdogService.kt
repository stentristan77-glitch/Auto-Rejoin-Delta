package com.rejoin.watchdog

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Every few seconds, checks which app is in the foreground.
 * If the watched app (Roblox) was open and is now gone for longer than
 * the chosen delay, it opens the private server link again.
 */
class WatchdogService : Service() {

    companion object {
        @Volatile var running = false
        private const val CHANNEL = "watchdog"
        private const val ACTION_STOP = "stop"
        private const val CHECK_MS = 2000L
        private const val COOLDOWN_MS = 25_000L // give Roblox time to load after relaunch
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var prefs: Prefs
    private var wakeLock: PowerManager.WakeLock? = null

    private var sawTargetOpen = false
    private var goneSince = 0L
    private var lastLaunch = 0L
    private var currentForeground: String? = null
    private var lastEventTime = 0L

    private val tick = object : Runnable {
        override fun run() {
            check()
            handler.postDelayed(this, CHECK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        prefs = Prefs(this)
        startInForeground()
        if (!running) {
            running = true
            lastEventTime = System.currentTimeMillis() - 60 * 60 * 1000
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "rejoin:watch").apply {
                setReferenceCounted(false)
                acquire()
            }
            handler.post(tick)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        wakeLock?.release()
        super.onDestroy()
    }

    private fun check() {
        val target = prefs.pkg
        updateForeground()
        val fg = currentForeground
        val now = System.currentTimeMillis()

        if (fg == target) {
            sawTargetOpen = true
            goneSince = 0L
            return
        }

        // Don't fight the user while they're in this app (e.g. to press Stop)
        if (fg == packageName) { goneSince = 0L; return }

        // Only relaunch after Roblox has actually been opened once
        if (!sawTargetOpen) return

        // Skip while the screen is off
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return

        if (goneSince == 0L) goneSince = now
        val waited = now - goneSince >= prefs.delaySec * 1000L
        val cooled = now - lastLaunch >= COOLDOWN_MS
        if (waited && cooled) {
            lastLaunch = now
            goneSince = 0L
            Launcher.open(this, prefs.link, target)
        }
    }

    /** Reads new usage events and remembers the most recently resumed app. */
    private fun updateForeground() {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(lastEventTime, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> currentForeground = e.packageName
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED ->
                    if (e.packageName == currentForeground) currentForeground = null
            }
            lastEventTime = e.timeStamp + 1
        }
    }

    private fun startInForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Watcher", NotificationManager.IMPORTANCE_LOW)
        )
        val stopIntent = PendingIntent.getService(
            this, 0, Intent(this, WatchdogService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = PendingIntent.getActivity(
            this, 1, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_rotate)
            .setContentTitle("Roblox Rejoin is watching")
            .setContentText("Will reopen your private server if ${prefs.pkg} closes")
            .setContentIntent(openIntent)
            .addAction(Notification.Action.Builder(null, "Stop", stopIntent).build())
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, n)
        }
    }
}
