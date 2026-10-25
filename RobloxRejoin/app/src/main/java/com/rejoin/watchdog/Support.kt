package com.rejoin.watchdog

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast

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
