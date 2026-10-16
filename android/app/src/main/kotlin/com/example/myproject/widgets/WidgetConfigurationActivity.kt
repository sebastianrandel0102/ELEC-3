package com.example.myproject.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.widget.Button
import com.example.myproject.MainActivity

/** Launcher-owned result Activity; Flutter configuration uses the existing engine. */
class WidgetConfigurationActivity : Activity() {
    companion object { const val COMPLETE = "com.example.myproject.WIDGET_CONFIGURATION_COMPLETE" }
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val completion = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.getIntExtra("id", -1) != widgetId) return
            val saved = intent.getBooleanExtra("saved", false) && WidgetStore(context).config(widgetId) != null
            setResult(if (saved) RESULT_OK else RESULT_CANCELED,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            finish()
        }
    }
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        if (widgetId !in WidgetStore(this).installed()) { finish(); return }
        val filter = IntentFilter(COMPLETE)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(completion, filter, RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(completion, filter)
        val button = Button(this).apply {
            text = "Customize your SaveTrack widget"
            setOnClickListener { openApp() }
        }
        setContentView(button)
        if (state == null) openApp()
    }
    private fun openApp() {
        startActivity(Intent(this, MainActivity::class.java)
            .setAction("savetrack.widget")
            .putExtra("widgetId", widgetId).putExtra("widgetAction", "configure").putExtra("launcherConfiguration", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP))
    }
    override fun onDestroy() {
        try { unregisterReceiver(completion) } catch (_: IllegalArgumentException) { }
        super.onDestroy()
    }
}
