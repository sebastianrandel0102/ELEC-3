package com.example.myproject.widgets

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

/** All store objects share this lock; receiver input is processed in arrival order. */
class QuickSaveStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("savetrack_widgets", Context.MODE_PRIVATE)
    companion object { val lock = Any() }
    private fun read(key: String): JSONObject? = try { prefs.getString(key, null)?.let { JSONObject(it) } } catch (_: Exception) { null }
    fun state(id: Int): JSONObject = synchronized(lock) {
        read("input_$id") ?: JSONObject().put("stage", "entry").put("amount", "").put("page", 0).put("flow", "initial")
    }
    fun operation(id: Int): JSONObject? = synchronized(lock) { read("operation_$id") }
    fun pending(): JSONObject? = synchronized(lock) {
        WidgetStore(context).installed().keys.firstNotNullOfOrNull { id ->
            val config = WidgetStore(context).config(id)
            operation(id)?.takeIf { config != null && state(id).optString("stage") == "pending" &&
                it.optLong("revision") == config.optLong("revision") && it.optString("uid") == WidgetStore(context).session() }
        }
    }
    private fun write(id: Int, state: JSONObject, operation: JSONObject? = operation(id)) {
        val edit = prefs.edit().putString("input_$id", state.toString())
        if (operation == null) edit.remove("operation_$id") else edit.putString("operation_$id", operation.toString())
        check(edit.commit())
    }
    fun dispatch(id: Int, revision: Long, flow: String, control: String): Boolean = synchronized(lock) {
        val store = WidgetStore(context)
        val config = store.config(id) ?: return false
        if (store.installed()[id] != "quickSave" || config.optLong("revision") != revision || config.optString("privacy") != "full") return false
        val state = state(id)
        if (flow != state.optString("flow")) return false
        val stage = state.optString("stage")
        if (stage == "pending") return false
        if (stage == "retry") {
            if (control != "retry" || operation(id) == null) return false
            state.put("stage", "pending"); write(id, state); return true
        }
        if (stage == "saved") {
            if (control != "new") return false
            write(id, JSONObject().put("stage", "entry").put("amount", "").put("page", 0).put("flow", UUID.randomUUID().toString()), null)
            return true
        }
        val snapshot = store.snapshot(id) ?: return false
        val goal = snapshot.optJSONObject("goal") ?: return false
        if (goal.optBoolean("canSave") != true || goal.optString("currency") != config.optString("currency")) return false
        val decimals = goal.optInt("currencyDigits", 2).coerceIn(0, 4)
        val shared = config.optJSONObject("goal")?.optBoolean("shared") == true
        if (stage == "review") {
            when (control) {
                "cancel" -> state.put("stage", "entry").put("flow", UUID.randomUUID().toString())
                "confirm" -> {
                    val amount = QuickSaveInput.review(state.optString("amount"), decimals, shared) ?: return false
                    val operation = JSONObject().put("id", id).put("uid", config.getString("uid"))
                        .put("revision", revision).put("goal", config.getJSONObject("goal"))
                        .put("currency", config.getString("currency")).put("amount", amount)
                        .put("requestId", UUID.randomUUID().toString())
                        .put("date", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
                    state.put("stage", "pending").put("flow", UUID.randomUUID().toString())
                    write(id, state, operation); return true
                }
                else -> return false
            }
        } else when {
            control == "review" -> {
                val amount = QuickSaveInput.review(state.optString("amount"), decimals, shared)
                if (amount == null) state.put("message", "Check amount and currency limits")
                else state.put("amount", amount).put("stage", "review").put("message", "").put("flow", UUID.randomUUID().toString())
            }
            control == "page" -> state.put("page", (state.optInt("page") + 1) % (if ((config.optJSONArray("presets")?.length() ?: 0) > 0) 5 else 4))
            control.startsWith("preset:") -> {
                val index = control.substringAfter(':').toIntOrNull() ?: return false
                val amount = config.optJSONArray("presets")?.optString(index) ?: return false
                if (QuickSaveInput.review(amount, decimals, shared) == null) return false
                state.put("amount", amount).put("message", "")
            }
            control == "cancel" -> state.put("amount", "").put("message", "")
            control == "back" || control == "clear" || control.startsWith("digit:") ->
                state.put("amount", QuickSaveInput.edit(state.optString("amount"), control, decimals)).put("message", "")
            else -> return false
        }
        write(id, state); true
    }
    fun complete(id: Int, request: String, success: Boolean): Unit = synchronized(lock) {
        val operation = operation(id) ?: return
        val config = WidgetStore(context).config(id) ?: return
        if (operation.optString("requestId") != request || operation.optString("uid") != config.optString("uid") || operation.optLong("revision") != config.optLong("revision")) return
        val state = state(id).put("stage", if (success) "saved" else "retry").put("flow", UUID.randomUUID().toString())
        write(id, state, if (success) null else operation)
        WidgetRenderer.update(context, id)
    }
}

class QuickSaveActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val pending = goAsync()
        executor.execute {
            try {
                val id = intent.getIntExtra("id", -1)
                val store = QuickSaveStore(context)
                if (store.dispatch(id, intent.getLongExtra("revision", -1), intent.getStringExtra("flow") ?: "", intent.getStringExtra("control") ?: "")) {
                    if (store.state(id).optString("stage") == "pending") QuickSaveJobService.schedule(context)
                    WidgetRenderer.update(context, id)
                }
            } catch (_: Exception) { /* Keep persisted state for recovery on the next tap. */ }
            finally { pending.finish() }
        }
    }
    companion object {
        const val ACTION = "com.example.myproject.QUICK_SAVE_INPUT"
        private val executor = Executors.newSingleThreadExecutor()
        fun action(context: Context, id: Int, revision: Long, flow: String, control: String): PendingIntent {
            val uri = Uri.Builder().scheme("savetrack-widget-input").authority("local")
                .appendPath(id.toString()).appendPath(revision.toString()).appendPath(flow).appendPath(control).build()
            val intent = Intent(context, QuickSaveActionReceiver::class.java).setAction(ACTION).setData(uri)
                .putExtra("id", id).putExtra("revision", revision).putExtra("flow", flow).putExtra("control", control)
            return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
