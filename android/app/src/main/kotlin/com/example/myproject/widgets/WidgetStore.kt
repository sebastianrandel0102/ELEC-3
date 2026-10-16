package com.example.myproject.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class WidgetStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("savetrack_widgets", Context.MODE_PRIVATE)
    companion object {
        val providers = linkedMapOf(
            "goal" to SaveTrackGoalWidget::class.java,
            "planner" to SaveTrackPlannerWidget::class.java,
            "quickSave" to SaveTrackQuickSaveWidget::class.java,
            "today" to SaveTrackTodayWidget::class.java,
        )
    }
    fun installed(): Map<Int, String> {
        val manager = AppWidgetManager.getInstance(context)
        return providers.flatMap { (type, cls) ->
            manager.getAppWidgetIds(ComponentName(context, cls)).map { it to type }
        }.toMap()
    }
    fun session(): String? = prefs.getString("session", null)
    fun config(id: Int): JSONObject? = decode(prefs.getString("config_$id", null))
        ?.takeIf { it.optInt("schemaVersion") == 1 && it.optString("uid") == session() }
    fun snapshot(id: Int): JSONObject? {
        val config = config(id) ?: return null
        return decode(prefs.getString("snapshot_$id", null))?.takeIf {
            validSnapshot(it, config)
        }
    }
    private fun decode(raw: String?): JSONObject? = try {
        raw?.let { JSONObject(it) }
    } catch (_: Exception) { null }
    @Synchronized fun setSession(uid: String?) {
        if (session() == uid) return
        val edit = prefs.edit()
        for (key in prefs.all.keys) {
            if (key.startsWith("config_") || key.startsWith("snapshot_")) edit.remove(key)
        }
        if (uid == null) edit.remove("session") else edit.putString("session", uid)
        check(edit.commit()) { "Could not clear widget storage" }
        WidgetRenderer.updateAll(context)
    }
    @Synchronized fun save(raw: String): JSONObject {
        require(raw.length < 8192)
        val data = JSONObject(raw)
        val id = data.getInt("id")
        require(data.optInt("schemaVersion") == 1 && data.getString("uid") == session())
        require(installed()[id] == data.getString("type")) { "Widget is no longer installed" }
        require(data.getString("theme") in listOf("emerald", "mint", "white", "system"))
        require(data.getString("privacy") in listOf("full", "progress", "hidden"))
        val goal = data.optJSONObject("goal")
        require(data.getString("type") == "planner" || goal != null)
        if (goal != null) {
            require(validId(goal.getString("id")))
            require(goal.get("shared") is Boolean)
            require(data.getString("currency").matches(Regex("[A-Z]{3}")))
        }
        val presets = data.optJSONArray("presets") ?: JSONArray()
        require(presets.length() <= 3)
        for (i in 0 until presets.length()) {
            val amount = presets.getString(i)
            require(amount.length <= 30 && amount.matches(Regex("\\d+(\\.\\d{1,4})?")))
            require(amount.toBigDecimal().signum() > 0)
        }
        val revision = prefs.getLong("revision", 0) + 1
        data.put("revision", revision)
        check(prefs.edit().putLong("revision", revision)
            .putString("config_$id", data.toString()).remove("snapshot_$id").commit())
        WidgetRenderer.update(context, id)
        return data
    }
    private fun validSnapshot(data: JSONObject, config: JSONObject): Boolean {
        if (!(data.optInt("schemaVersion") == 1 && data.optInt("id") == config.optInt("id") &&
        data.optString("uid") == session() && data.optLong("revision") == config.optLong("revision") &&
        data.optString("privacy") == config.optString("privacy") &&
        data.optString("type") == config.optString("type") && data.optLong("updatedAt") > 0)) return false
        if (data.optString("state") !in listOf("ready", "unavailable", "hidden")) return false
        val goal = data.optJSONObject("goal")
        if (goal != null) {
            if (goal.opt("percent") !is Number || goal.optInt("percent") !in 0..100 ||
                goal.opt("progress") !is Number || goal.optInt("progress") !in 0..1000 ||
                goal.optString("title").length !in 1..200) return false
            if (data.optString("privacy") == "full" && listOf("saved", "target", "remaining").any {
                goal.opt(it) !is String || goal.optString(it).length !in 1..100
            }) return false
        } else if (data.optString("state") == "ready" && data.optString("type") in listOf("goal", "quickSave")) return false
        val planner = data.optJSONObject("planner")
        if (planner?.optString("state") == "ready") {
            val total = planner.optInt("total", -1)
            if (total !in 0..100000 || planner.optInt("done", -1) !in 0..total ||
                planner.optInt("remaining", -1) != total - planner.optInt("done")) return false
            val tasks = planner.optJSONArray("tasks") ?: return false
            if (tasks.length() > 5) return false
            for (index in 0 until tasks.length()) {
                val task = tasks.optJSONObject(index) ?: return false
                if (!validId(task.optString("id")) || task.optString("title").length !in 1..500) return false
            }
        }
        return true
    }

    @Synchronized fun publish(uid: String, payloads: List<String>) {
        require(uid == session()) { "Session changed" }
        val ids = installed()
        val changed = mutableListOf<Int>()
        val edit = prefs.edit()
        for (raw in payloads) {
            require(raw.length < 65536)
            val data = JSONObject(raw)
            val id = data.optInt("id")
            val config = config(id) ?: continue
            if (ids[id] != data.optString("type") || !validSnapshot(data, config)) continue
            // Reject rather than retain private values in a hidden-mode payload.
            if (data.optString("privacy") == "hidden") {
                data.remove("goal"); data.remove("planner"); data.remove("thumbnail")
            } else if (data.optString("privacy") == "progress") {
                data.remove("thumbnail")
                data.optJSONObject("goal")?.let {
                    for (key in listOf("saved", "target", "remaining", "deadline", "presets", "currency")) it.remove(key)
                    it.put("title", "Savings goal")
                }
                data.optJSONObject("planner")?.put("tasks", JSONArray())
            }
            // A cached repaint must not renew the age of old financial facts.
            val previous = decode(prefs.getString("snapshot_$id", null))
            val freshness = if (data.optBoolean("cached")) {
                previous?.optLong("freshnessAt", previous.optLong("updatedAt"))
                    ?: data.optLong("updatedAt")
            } else data.optLong("confirmedAt", data.optLong("updatedAt"))
            data.put("freshnessAt", freshness)
            val value = data.toString()
            if (prefs.getString("snapshot_$id", null) != value) {
                edit.putString("snapshot_$id", value); changed.add(id)
            }
        }
        check(edit.commit())
        changed.forEach { WidgetRenderer.update(context, it) }
    }
    fun remove(ids: IntArray) {
        val edit = prefs.edit()
        ids.forEach { edit.remove("config_$it").remove("snapshot_$it") }
        check(edit.commit())
    }
    fun restored(old: IntArray, new: IntArray) {
        // Restored IDs never inherit financial selections or account bindings.
        remove(old + new)
        new.forEach { WidgetRenderer.update(context, it) }
    }
    fun prune() {
        val ids = installed().keys
        val edit = prefs.edit()
        prefs.all.keys.filter { it.startsWith("config_") || it.startsWith("snapshot_") }.forEach {
            if (it.substringAfter('_').toIntOrNull() !in ids) edit.remove(it)
        }
        edit.apply()
    }
    fun instances(): List<Map<String, Any?>> {
        prune()
        return installed().map { (id, type) -> mapOf("id" to id, "type" to type, "config" to config(id)?.toString()) }
    }
    private fun validId(value: String) = value.isNotEmpty() && value.length <= 128 &&
        '/' !in value && value.none { it.code < 32 }
}
