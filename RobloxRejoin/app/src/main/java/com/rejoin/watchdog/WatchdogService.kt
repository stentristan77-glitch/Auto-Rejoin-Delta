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
import java.io.File

/**
 * Every 2 seconds:
 *  1. If the watched app (Delta/Roblox) closed, reopen the private server link.
 *  2. If the app is open but the heartbeat file from the in-game script stopped
 *     updating (error 279, stuck loading, disconnected, frozen), reopen the link.
 */
class WatchdogService : Service() {

    companion object {
        @Volatile var running = false
        private const val CHANNEL = "watchdog"
        private const val ACTION_STOP = "stop"
        private const val CHECK_MS = 2000L
        private const val RETRY_MS = 90_000L // if the game didn't come back, try the link again after this
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var prefs: Prefs
    private var wakeLock: PowerManager.WakeLock? = null

    private var sawTargetOpen = false
    private var waitingForRelaunch = false
    private var goneSince = 0L
    private var targetSince = 0L
    private var lastLaunch = 0L
    private var currentForeground: String? = null
    private var currentClass: String? = null
    private var lastEventTime = 0L

    private val tick = object : Runnable {
        override fun run() {
            try { check() } catch (e: Exception) { }
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
            if (targetSince == 0L) targetSince = now
            sawTargetOpen = true
            waitingForRelaunch = false
            goneSince = 0L
            checkHeartbeat(now, target)
            return
        }

        // Unknown foreground (e.g. mid screen switch) - don't count it as closed
        if (fg == null) return
        targetSince = 0L

        // Don't fight the user while they're in this app (e.g. to press Stop)
        if (fg == packageName) { goneSince = 0L; return }

        // Skip while the screen is off
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return

        // Already reopened once: only retry if the game still hasn't come back after a while
        if (waitingForRelaunch) {
            if (now - lastLaunch >= RETRY_MS) {
                lastLaunch = now
                Launcher.open(this, prefs.link, target)
            }
            return
        }

        // Only relaunch after the game has actually been opened once
        if (!sawTargetOpen) return

        if (goneSince == 0L) goneSince = now
        if (now - goneSince >= prefs.delaySec * 1000L) {
            lastLaunch = now
            goneSince = 0L
            sawTargetOpen = false
            waitingForRelaunch = true
            Launcher.open(this, prefs.link, target)
        }
    }

    /**
     * The game is on screen. If the heartbeat file hasn't been updated for
     * longer than the stale time, we're not really in a server -> rejoin.
     */
    private fun checkHeartbeat(now: Long, target: String) {
        val path = prefs.heartbeatPath
        if (path.isBlank()) return
        val beat = File(path).lastModified()
        // File missing or unreadable: never act, so a wrong path can't cause spam
        if (beat == 0L) return
        val lastSignOfLife = maxOf(beat, targetSince, lastLaunch)
        if (now - lastSignOfLife >= prefs.staleSec * 1000L) {
            lastLaunch = now
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
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    currentForeground = e.packageName
                    currentClass = e.className
                }
                // Only clear if the exact screen that was showing got paused,
                // so switching between screens inside the same app isn't seen as closing
                UsageEvents.Event.ACTIVITY_PAUSED ->
                    if (e.packageName == currentForeground && e.className == currentClass) {
                        currentForeground = null
                        currentClass = null
                    }
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
            .setContentText("Will reopen your private server if ${prefs.pkg} closes or gets stuck")
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
