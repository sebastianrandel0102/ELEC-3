package com.example.myproject.widgets

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Network work lives outside the receiver; Android owns scheduling/restart. */
class QuickSaveJobService : JobService() {
    private var engine: FlutterEngine? = null
    private var active: JobParameters? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish(true) }
    override fun onStartJob(params: JobParameters): Boolean {
        if (active != null) return false
        active = params
        running = true
        if (QuickSaveStore(this).pending() == null) { finish(false); return false }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationCompleteAsync(applicationContext, null, handler) {
                if (active !== params) return@ensureInitializationCompleteAsync
                try {
                    val background = FlutterEngine(applicationContext)
                    engine = background
                    MethodChannel(background.dartExecutor.binaryMessenger, "savetrack/widget_background").setMethodCallHandler { call, result ->
                        try {
                            when (call.method) {
                                "next" -> result.success(QuickSaveStore(this).pending()?.toString())
                                "configs" -> result.success(WidgetStore(this).installed().keys.mapNotNull { WidgetStore(this).config(it)?.toString() })
                                "defer" -> {
                                    val store = QuickSaveStore(this)
                                    while (true) {
                                        val operation = store.pending() ?: break
                                        store.complete(operation.getInt("id"), operation.getString("requestId"), false)
                                    }
                                    result.success(null)
                                }
                                "authorize" -> {
                                    val id = call.argument<Int>("id")!!
                                    val operation = QuickSaveStore(this).operation(id)
                                    val config = WidgetStore(this).config(id)
                                    result.success(config != null && operation != null &&
                                        operation.optString("requestId") == call.argument<String>("requestId") &&
                                        operation.optString("uid") == WidgetStore(this).session() &&
                                        operation.optLong("revision") == config.optLong("revision"))
                                }
                                "publish" -> {
                                    WidgetStore(this).publish(call.argument<String>("uid")!!, call.argument<List<String>>("snapshots")!!)
                                    result.success(null)
                                }
                                "result" -> {
                                    QuickSaveStore(this).complete(call.argument<Int>("id")!!, call.argument<String>("requestId")!!, call.argument<Boolean>("success") == true)
                                    result.success(null)
                                }
                                "done" -> { result.success(null); handler.post { finish(false) } }
                                else -> result.notImplemented()
                            }
                        } catch (_: Exception) { result.error("widget_background", "Widget state changed", null) }
                    }
                    background.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "widgetBackgroundMain"))
                } catch (_: Exception) { finish(true) }
            }
            handler.postDelayed(timeout, 120000)
        } catch (_: Exception) { finish(true) }
        return true
    }
    private fun finish(retry: Boolean) {
        val params = active ?: return
        active = null
        running = false
        handler.removeCallbacks(timeout)
        engine?.destroy(); engine = null
        jobFinished(params, retry)
        if (!retry && QuickSaveStore(this).pending() != null) schedule(this)
    }
    override fun onStopJob(params: JobParameters): Boolean {
        active = null
        running = false
        handler.removeCallbacks(timeout)
        engine?.destroy(); engine = null
        return QuickSaveStore(this).pending() != null
    }
    companion object {
        private const val JOB_ID = 87001
        @Volatile private var running = false
        fun schedule(context: Context) {
            val scheduler = context.getSystemService(JobScheduler::class.java)
            if (running) return
            val result = scheduler.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, QuickSaveJobService::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPersisted(true)
                .setBackoffCriteria(30000, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
            if (result != JobScheduler.RESULT_SUCCESS) {
                val store = QuickSaveStore(context)
                while (true) {
                    val operation = store.pending() ?: break
                    store.complete(operation.getInt("id"), operation.getString("requestId"), false)
                }
            }
        }
    }
}
