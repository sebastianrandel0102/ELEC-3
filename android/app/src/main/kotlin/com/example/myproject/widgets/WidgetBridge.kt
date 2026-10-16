package com.example.myproject.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import com.example.myproject.MainActivity
import io.flutter.plugin.common.MethodChannel

class WidgetBridge(private val activity: MainActivity, private val channel: MethodChannel) {
    private var pending: Map<String, Any?>? = null
    private var ready = false
    private val store = WidgetStore(activity)
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takeLaunch" -> { ready = true; result.success(pending); pending = null }
                    "setSession" -> { store.setSession(call.argument<String>("uid")); result.success(null) }
                    "instances" -> result.success(store.instances())
                    "saveConfig" -> result.success(store.save(call.arguments as String).toString())
                    "publish" -> {
                        store.publish(call.argument<String>("uid")!!, call.argument<List<String>>("snapshots")!!)
                        result.success(null)
                    }
                    "completeConfiguration" -> {
                        val id = call.argument<Int>("id")!!
                        val saved = call.argument<Boolean>("saved") == true
                        activity.sendBroadcast(Intent(WidgetConfigurationActivity.COMPLETE).setPackage(activity.packageName)
                            .putExtra("id", id).putExtra("saved", saved))
                        // Launcher setup returns home; in-app editing does not send this call.
                        activity.moveTaskToBack(true)
                        result.success(null)
                    }
                    "canPin" -> result.success(Build.VERSION.SDK_INT >= 26 && AppWidgetManager.getInstance(activity).isRequestPinAppWidgetSupported)
                    "pin" -> {
                        val cls = WidgetStore.providers[call.argument<String>("type")]
                        val manager = AppWidgetManager.getInstance(activity)
                        result.success(if (Build.VERSION.SDK_INT >= 26 && cls != null && manager.isRequestPinAppWidgetSupported)
                            manager.requestPinAppWidget(ComponentName(activity, cls), null, null) else false)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("widget_error", error.message ?: "Widget operation failed", null)
            }
        }
    }
    fun accept(intent: Intent?) {
        if (intent?.action != "savetrack.widget") return
        val id = intent.getIntExtra("widgetId", -1)
        val action = intent.getStringExtra("widgetAction") ?: return
        if (id !in store.installed() || action !in listOf("configure", "goal", "save", "planner", "task", "dashboard", "coach")) return
        val data = mutableMapOf<String, Any?>("id" to id, "action" to action)
        data["launcher"] = intent.getBooleanExtra("launcherConfiguration", false)
        if (intent.hasExtra("preset")) data["preset"] = intent.getIntExtra("preset", -1)
        intent.getStringExtra("taskId")?.let { data["taskId"] = it }
        intent.removeExtra("widgetId") // Do not replay after activity recreation.
        if (ready) channel.invokeMethod("launch", data) else pending = data
    }
}
