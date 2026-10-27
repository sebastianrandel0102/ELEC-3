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
                    "preview" -> {
                        val type = call.argument<String>("type")!!
                        require(type in WidgetStore.providers)
                        val width = (call.argument<Number>("width")!!).toFloat().coerceIn(110f, 600f)
                        val height = (call.argument<Number>("height")!!).toFloat().coerceIn(56f, 700f)
                        val configuration = android.content.res.Configuration(activity.resources.configuration)
                        configuration.fontScale = (call.argument<Number>("fontScale")?.toFloat() ?: 1f).coerceIn(1f, 3f)
                        configuration.uiMode = (configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK.inv()) or
                            if (call.argument<Boolean>("dark") == true) android.content.res.Configuration.UI_MODE_NIGHT_YES else android.content.res.Configuration.UI_MODE_NIGHT_NO
                        val context = activity.createConfigurationContext(configuration)
                        val config = org.json.JSONObject(call.argument<String>("config")!!)
                        val snapshot = org.json.JSONObject(call.argument<String>("snapshot")!!)
                        val views = WidgetRenderer.render(context, -1, type, config, snapshot, width, height)
                        val root = views.apply(context, android.widget.FrameLayout(context))
                        val density = context.resources.displayMetrics.density
                        val w = (width * density).toInt().coerceIn(1, 1800)
                        val h = (height * density).toInt().coerceIn(1, 2100)
                        root.measure(android.view.View.MeasureSpec.makeMeasureSpec(w, android.view.View.MeasureSpec.EXACTLY),
                            android.view.View.MeasureSpec.makeMeasureSpec(h, android.view.View.MeasureSpec.EXACTLY))
                        root.layout(0, 0, w, h)
                        val bitmap = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
                        root.draw(android.graphics.Canvas(bitmap))
                        val bytes = java.io.ByteArrayOutputStream()
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, bytes)
                        bitmap.recycle()
                        result.success(bytes.toByteArray())
                    }
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
