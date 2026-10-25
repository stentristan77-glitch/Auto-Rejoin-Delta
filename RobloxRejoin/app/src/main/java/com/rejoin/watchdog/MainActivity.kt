package com.rejoin.watchdog

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.text.InputType
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {

    private lateinit var linkInput: EditText
    private lateinit var pkgInput: EditText
    private lateinit var delayInput: EditText
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = Prefs(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 64, 48, 48)
        }

        fun label(text: String) = TextView(this).apply {
            this.text = text
            textSize = 15f
            setPadding(0, 32, 0, 8)
        }.also { root.addView(it) }

        TextView(this).apply {
            text = "Roblox Rejoin"
            textSize = 26f
        }.also { root.addView(it) }

        label("Private server link")
        linkInput = EditText(this).apply {
            hint = "https://www.roblox.com/share?code=...&type=Server"
            setText(prefs.link)
            inputType = InputType.TYPE_TEXT_VARIATION_URI
        }.also { root.addView(it, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)) }

        label("App to watch (package name)")
        pkgInput = EditText(this).apply {
            setText(prefs.pkg)
            setSingleLine()
        }.also { root.addView(it, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)) }

        label("Seconds to wait before reopening")
        delayInput = EditText(this).apply {
            setText(prefs.delaySec.toString())
            inputType = InputType.TYPE_CLASS_NUMBER
        }.also { root.addView(it, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)) }

        fun button(text: String, onClick: () -> Unit) = Button(this).apply {
            this.text = text
            setOnClickListener { onClick() }
        }.also { root.addView(it, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT)) }

        label("Step 1 - permissions")
        button("Allow usage access") {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
        button("Allow display over other apps") {
            startActivity(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            )
        }
        button("Turn off battery optimisation") {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }

        label("Step 2 - run")
        button("Test link now") {
            save(prefs)
            Launcher.open(this, prefs.link, prefs.pkg)
        }
        button("START watching") { start(prefs) }
        button("STOP watching") {
            stopService(Intent(this, WatchdogService::class.java))
            refresh()
        }

        status = TextView(this).apply { setPadding(0, 32, 0, 0) }
        root.addView(status)

        setContentView(ScrollView(this).apply { addView(root) })

        if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun save(prefs: Prefs) {
        prefs.link = linkInput.text.toString().trim()
        prefs.pkg = pkgInput.text.toString().trim().ifEmpty { "com.roblox.client" }
        prefs.delaySec = delayInput.text.toString().toIntOrNull()?.coerceIn(2, 600) ?: 5
    }

    private fun start(prefs: Prefs) {
        save(prefs)
        when {
            prefs.link.isEmpty() -> toast("Paste your private server link first")
            !hasUsageAccess() -> toast("Allow usage access first")
            !Settings.canDrawOverlays(this) -> toast("Allow display over other apps first")
            else -> {
                val i = Intent(this, WatchdogService::class.java)
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                toast("Watching ${prefs.pkg}")
            }
        }
        refresh()
    }

    private fun refresh() {
        val usage = if (hasUsageAccess()) "OK" else "MISSING"
        val overlay = if (Settings.canDrawOverlays(this)) "OK" else "MISSING"
        val running = if (WatchdogService.running) "RUNNING" else "stopped"
        status.text = "Usage access: $usage\nDisplay over apps: $overlay\nWatcher: $running"
    }

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
