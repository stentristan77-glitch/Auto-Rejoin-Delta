package com.rejoin.watchdog

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.os.Build
import android.os.SystemClock

class Prefs(ctx: Context) {
    private val sp = ctx.getSharedPreferences("rejoin", Context.MODE_PRIVATE)

    var link: String
        get() = sp.getString("link", "") ?: ""
        set(v) = sp.edit().putString("link", v).apply()

    var pkg: String
        get() = sp.getString("pkg", "com.roblox.client") ?: "com.roblox.client"
        set(v) = sp.edit().putString("pkg", v).apply()

    var delaySec: Int
        get() = sp.getInt("delay", 5)
        set(v) = sp.edit().putInt("delay", v).apply()

    var heartbeatPath: String
        get() = sp.getString("hb", DEFAULT_HB) ?: DEFAULT_HB
        set(v) = sp.edit().putString("hb", v).apply()

    var staleSec: Int
        get() = sp.getInt("stale", 120)
        set(v) = sp.edit().putInt("stale", v).apply()

    /** True while the user wants watching on (survives the app being killed). */
    var watching: Boolean
        get() = sp.getBoolean("watching", false)
        set(v) = sp.edit().putBoolean("watching", v).commit().let { }

    companion object {
        const val DEFAULT_HB = "/storage/emulated/0/Delta/Workspace/rejoin_heartbeat.txt"
    }
}

object Launcher {
    /** Opens the private server link, preferring the watched app itself. */
    fun open(ctx: Context, link: String, pkg: String) {
        if (link.isBlank()) return
        val base = Intent(Intent.ACTION_VIEW, Uri.parse(link))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        try {
            ctx.startActivity(Intent(base).setPackage(pkg))
        } catch (e: ActivityNotFoundException) {
            try {
                ctx.startActivity(base)
            } catch (e2: Exception) {
                Toast.makeText(ctx, "Couldn't open link: ${e2.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
}

/** A system alarm every ~60s that restarts the watcher if Android killed it. */
object Keepalive {
    private fun pi(ctx: Context) = PendingIntent.getBroadcast(
        ctx, 7, Intent(ctx, KeepaliveReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + 60_000L,
            pi(ctx)
        )
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi(ctx))
    }

    fun startService(ctx: Context) {
        val i = Intent(ctx, WatchdogService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        } catch (e: Exception) { }
    }
}

/** Fires from the alarm and after the phone restarts. */
class KeepaliveReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        val prefs = Prefs(ctx)
        if (!prefs.watching) return
        if (!WatchdogService.running) Keepalive.startService(ctx)
        Keepalive.schedule(ctx)
    }
}
