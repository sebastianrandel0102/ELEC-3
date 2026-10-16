package com.example.myproject.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RemoteViews
import com.example.myproject.MainActivity
import com.example.myproject.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object WidgetRenderer {
    private val ink = Color.rgb(20, 54, 43)
    private val white = Color.WHITE
    private val muted = Color.rgb(82, 110, 97)
    private val mint = Color.rgb(117, 231, 191)

    fun updateAll(context: Context) { WidgetStore(context).installed().keys.forEach { update(context, it) } }
    fun update(context: Context, id: Int) {
        val manager = AppWidgetManager.getInstance(context)
        val store = WidgetStore(context)
        val type = store.installed()[id] ?: return
        val options = manager.getAppWidgetOptions(id)
        val config = store.config(id)
        val snapshot = store.snapshot(id)
        val views = if (Build.VERSION.SDK_INT >= 31) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                RemoteViews(sizes.filter { it.width > 0 && it.height > 0 }.take(16).associateWith {
                    render(context, id, type, config, snapshot, it.width, it.height)
                }.ifEmpty { mapOf(SizeF(270f, 190f) to render(context, id, type, config, snapshot, 270f, 190f)) })
            } else legacy(context, id, type, config, snapshot, options)
        } else legacy(context, id, type, config, snapshot, options)
        manager.updateAppWidget(id, views)
    }
    private fun legacy(context: Context, id: Int, type: String, config: JSONObject?, data: JSONObject?, options: Bundle): RemoteViews {
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 270).coerceAtLeast(110).toFloat()
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110).coerceAtLeast(56).toFloat()
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minW.toInt()).coerceAtLeast(minW.toInt()).toFloat()
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 190).coerceAtLeast(minH.toInt()).toFloat()
        return RemoteViews(render(context, id, type, config, data, maxW, minH),
            render(context, id, type, config, data, minW, maxH))
    }
    private fun action(context: Context, id: Int, action: String, preset: Int? = null, taskId: String? = null): PendingIntent {
        val uri = Uri.Builder().scheme("savetrack-widget").authority("action")
            .appendPath(id.toString()).appendPath(action)
            .appendQueryParameter("preset", preset?.toString() ?: "")
            .appendQueryParameter("task", taskId ?: "").build()
        val intent = Intent(context, MainActivity::class.java).setAction("savetrack.widget").setData(uri)
            .putExtra("widgetId", id).putExtra("widgetAction", action)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        preset?.let { intent.putExtra("preset", it) }
        taskId?.let { intent.putExtra("taskId", it) }
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun render(context: Context, id: Int, type: String, config: JSONObject?, data: JSONObject?, width: Float, height: Float): RemoteViews {
        val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        val size = WidgetLayoutResolver.resolve(width, height, scale)
        val compact = size == WidgetSize.COMPACT
        val w = width / scale
        val h = height / scale
        val dark = when (config?.optString("theme")) {
            "emerald" -> true
            "mint", "white" -> false
            "system" -> (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            else -> type != "planner"
        }
        val foreground = if (dark) white else ink
        val secondary = if (dark) Color.rgb(217, 246, 233) else muted
        val views = RemoteViews(context.packageName, if (compact) R.layout.st_widget_compact else R.layout.st_widget)
        if (!compact) {
            // Hosts may reapply the same layout instead of inflating it again.
            // Reset optional views explicitly so an old private photo cannot
            // survive a privacy change, logout, or unavailable snapshot.
            views.setViewVisibility(R.id.st_cover, View.GONE)
            views.setImageViewResource(R.id.st_cover, 0)
            views.setViewVisibility(R.id.st_actions, View.GONE)
            views.setViewVisibility(R.id.st_updated, View.GONE)
            views.setTextViewText(R.id.st_updated, "")
        }
        val background = if (dark) R.drawable.st_widget_emerald else if (config?.optString("theme") == "white") R.drawable.st_widget_white else R.drawable.st_widget_mint
        views.setInt(android.R.id.background, "setBackgroundResource", background)
        var target = when (type) { "goal" -> "goal"; "quickSave" -> "save"; "planner" -> "planner"; else -> "dashboard" }
        val now = System.currentTimeMillis()
        val expired = data != null && (now - data.optLong("freshnessAt", data.optLong("updatedAt")) > 24 * 60 * 60 * 1000L || data.optLong("updatedAt") > now + 300000)
        val neutral = when {
            WidgetStore(context).session() == null -> "Sign in to SaveTrack"
            config == null -> "Choose your widget settings"
            data == null || expired -> "Open SaveTrack to refresh"
            data.optString("state") == "hidden" -> "Open SaveTrack"
            data.optString("state") == "unavailable" && type != "today" -> "Choose another goal"
            else -> null
        }
        if (config == null || data?.optString("state") == "unavailable") target = "configure"
        if (data?.optString("state") == "hidden" || expired) target = "dashboard"
        views.setOnClickPendingIntent(android.R.id.background, action(context, id, target))
        val goal = data?.optJSONObject("goal")
        val dateValid = data?.optString("day") == SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()) &&
            data.optInt("timezoneOffsetMinutes") == TimeZone.getDefault().getOffset(now) / 60000
        val planner = if (dateValid) data.optJSONObject("planner")?.takeIf { it.optString("state") == "ready" } else null
        if (type == "today" && neutral == null) {
            return today(context, id, config, data, goal, planner, width, height, dark, background)
        }
        if (compact) {
            val title = if (neutral != null) "SaveTrack" else when (type) { "planner" -> SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date()); "quickSave" -> "Quick Save"; "today" -> "Saved · tasks"; else -> goal?.optString("title") ?: "SaveTrack" }
            val value = if (neutral != null) when (neutral) {
                "Sign in to SaveTrack" -> "Sign in"
                "Open SaveTrack to refresh" -> "Refresh"
                "Open SaveTrack" -> "Open app"
                else -> "Set up"
            } else when (type) {
                "planner" -> planner?.let { "${it.optInt("remaining")} left" } ?: "Refresh"
                "quickSave" -> if (w < 160) "Add" else "Add Savings"
                "today" -> "${goal?.let { "${it.optInt("percent")}%" } ?: "—"} · ${planner?.optInt("remaining")?.toString() ?: "—"}"
                else -> "${goal?.optInt("percent") ?: 0}%"
            }
            views.setViewVisibility(R.id.st_compact_logo, if (type == "today") View.GONE else View.VISIBLE)
            views.setContentDescription(android.R.id.background, "$title. $value")
            views.setTextViewText(R.id.st_compact_title, title)
            views.setTextViewText(R.id.st_compact_value, value)
            views.setTextColor(R.id.st_compact_title, secondary)
            views.setTextColor(R.id.st_compact_value, foreground)
            views.setViewVisibility(R.id.st_compact_title, if (h < 55 || neutral != null) View.GONE else View.VISIBLE)
            views.setTextViewTextSize(R.id.st_compact_value, TypedValue.COMPLEX_UNIT_SP, if (neutral != null) 14f else 17f)
            return views
        }
        views.setTextColor(R.id.st_brand, secondary)
        views.removeAllViews(R.id.st_body)
        views.removeAllViews(R.id.st_actions)
        var availableBodyPixels = bodyHeight(context, views, width, height)
        fun addBody(row: RemoteViews) {
            val parent = LinearLayout(context)
            val view = row.apply(context, parent)
            val requestedHeight = view.layoutParams?.height ?: ViewGroup.LayoutParams.WRAP_CONTENT
            view.measure(View.MeasureSpec.makeMeasureSpec(((width - 24) * context.resources.displayMetrics.density).toInt().coerceAtLeast(1), View.MeasureSpec.EXACTLY),
                if (requestedHeight >= 0) View.MeasureSpec.makeMeasureSpec(requestedHeight, View.MeasureSpec.EXACTLY)
                else View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
            val margins = view.layoutParams as? ViewGroup.MarginLayoutParams
            val needed = view.measuredHeight + (margins?.topMargin ?: 0) + (margins?.bottomMargin ?: 0)
            if (needed <= availableBodyPixels) {
                views.addView(R.id.st_body, row)
                availableBodyPixels -= needed
            }
        }
        fun addText(text: String, sp: Float = 14f, color: Int = foreground, money: Boolean = false, container: Int = R.id.st_body) {
            val row = text(context, text, sp, color, money)
            if (container == R.id.st_body) addBody(row) else views.addView(container, row)
        }
        if (neutral != null) {
            addText(neutral, 20f)
            if (h >= 160) addText("Tap to open SaveTrack", 13f, secondary)
            return views
        }
        val actions = size >= WidgetSize.MEDIUM && h >= 210 || type == "quickSave" && h >= 165
        val footer = h >= 310
        views.setViewVisibility(R.id.st_actions, if (actions) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.st_updated, if (footer) View.VISIBLE else View.GONE)
        if (footer) {
            val stamp = data?.optLong("confirmedAt", 0) ?: 0
            views.setTextViewText(R.id.st_updated, if (data?.optBoolean("cached") == true || stamp == 0L)
                "Saved snapshot · open app to sync" else "Updated ${SimpleDateFormat("MMM d, HH:mm", Locale.getDefault()).format(Date(stamp))}")
            views.setTextColor(R.id.st_updated, secondary)
        }
        var budget = h - 48 - (if (actions) 56 else 0) - (if (footer) 24 else 0)
        val full = config?.optString("privacy") == "full"
        if (full && size >= WidgetSize.EXPANDED && cover(context, views, data)) budget -= 12
        // Measure the actual native header/footer and row heights. Font fallback,
        // currency glyphs and host text scaling can exceed estimated sp budgets.
        availableBodyPixels = bodyHeight(context, views, width, height)
        fun goalSummary(limit: Float) {
            if (goal == null) { addText("Choose a savings goal", 16f); return }
            addText(goal.optString("title"), 15f)
            val amountSize = fittingAmountSize(context, goal.optString("saved"), width - 24f, if (w >= 250) 23f else 18f)
            if (full && limit >= 110 && w >= 180 && amountSize != null) {
                addText(goal.optString("saved"), amountSize, money = true)
                addText("of ${goal.optString("target")}", 12f, secondary, money = true)
            } else addText("${goal.optInt("percent")}% completed", 23f)
            addBody(progress(context, goal.optInt("progress"), dark))
            if (limit >= 115) addText("${goal.optInt("percent")}% · ${goal.optString("status")}", 12f, secondary)
            if (full && limit >= 165) {
                addText("${goal.optString("remaining")} remaining", 13f, secondary, money = true)
                if (goal.has("deadline")) addText("Target date · ${goal.optString("deadline")}", 12f, secondary)
            }
        }
        when (type) {
            "goal" -> {
                goalSummary(budget)
                if (actions) {
                    if (goal?.optBoolean("canSave") == true) button(context, views, id, "Add Savings", "save")
                    if (w >= 280) button(context, views, id, "Open Goal", "goal")
                }
            }
            "planner" -> {
                addText(SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date()), 15f)
                if (planner == null) addText("Open Planner to refresh", 18f)
                else {
                    val total = planner.optInt("total")
                    addText(if (total == 0) "All clear for today" else "${planner.optInt("remaining")} tasks left", 23f)
                    budget -= 50
                    if (budget >= 35) {
                        addText(if (total == 0) "No tasks scheduled." else "${planner.optInt("done")} / $total completed", 12f, secondary)
                        addBody(progress(context, planner.optInt("progress"), dark))
                        budget -= 32
                    }
                    val rows = ((budget - 4) / 50).toInt().coerceIn(0, 5)
                    addTasks(context, id, planner, rows, dark, ::addBody)
                }
                if (actions) button(context, views, id, "Open Planner", "planner")
            }
            "quickSave" -> {
                addText("Quick Save", 23f)
                addText(goal?.let { (if (full) "${it.optString("currency")} · " else "") + it.optString("title") } ?: "Choose a goal", 14f, secondary)
                budget -= 50
                val presets = goal?.optJSONArray("presets")
                val rawPresets = config?.optJSONArray("presets")
                if (full && goal?.optBoolean("canSave") == true && w >= 250 && budget >= 55 && presets != null && rawPresets != null) {
                    val row = RemoteViews(context.packageName, R.layout.st_widget_actions)
                    row.removeAllViews(R.id.st_action_row)
                    for (index in 0 until presets.length().coerceAtMost(3)) {
                        val button = actionButton(context, "+${rawPresets.optString(index)}", presets.optString(index), action(context, id, "save", index))
                        row.addView(R.id.st_action_row, button)
                    }
                    addBody(row)
                    budget -= 55
                }
                if (budget >= 40) addText("Review and confirm savings in the app.", 12f, secondary, money = true)
                if (actions) button(context, views, id, if (goal?.optBoolean("canSave") == true) "Custom Amount" else "Open Goal", if (goal?.optBoolean("canSave") == true) "save" else "goal")
            }
        }
        return views
    }
    /** Today uses two equally sized summaries instead of the generic centered text stack. */
    private fun today(context: Context, id: Int, config: JSONObject?, data: JSONObject?, goal: JSONObject?, planner: JSONObject?,
                      width: Float, height: Float, dark: Boolean, background: Int): RemoteViews {
        val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        val w = width / scale
        val h = height / scale
        val stacked = h >= 190 && (w < 200 || height > width)
        val compact = !stacked && (h < 120 || w < 200)
        val layout = if (compact) R.layout.st_widget_today_compact else if (stacked) R.layout.st_widget_today_stacked else R.layout.st_widget_today
        val views = RemoteViews(context.packageName, layout)
        val foreground = if (dark) white else ink
        val secondary = if (dark) Color.rgb(217, 246, 233) else muted
        val full = config?.optString("privacy") == "full"
        val percent = goal?.let { "${it.optInt("percent")}%" } ?: "—"
        val remaining = planner?.optInt("remaining")?.coerceAtLeast(0)
        val tasks = remaining?.toString() ?: "—"
        val goalTitle = if (goal == null) "Choose a goal" else if (full) goal.optString("title") else "Goal progress"
        val taskTitle = when {
            planner == null -> "Open to refresh"
            planner.optInt("total") == 0 -> "No tasks today"
            remaining == 0 -> "All tasks done"
            remaining == 1 -> "task left"
            else -> "tasks left"
        }
        views.setInt(android.R.id.background, "setBackgroundResource", background)
        views.setOnClickPendingIntent(android.R.id.background, action(context, id, "dashboard"))
        views.setOnClickPendingIntent(R.id.st_today_goal, action(context, id, if (goal == null) "configure" else "goal"))
        views.setOnClickPendingIntent(R.id.st_today_tasks, action(context, id, "planner"))
        views.setContentDescription(R.id.st_today_goal, "Savings. $goalTitle. $percent")
        views.setContentDescription(R.id.st_today_tasks, if (planner == null) "Today's tasks. Open Planner to refresh" else
            "Today's tasks. $tasks $taskTitle. ${planner.optInt("done")} of ${planner.optInt("total")} completed")
        views.setTextViewText(R.id.st_today_goal_value, percent)
        views.setTextViewText(R.id.st_today_tasks_value, tasks)
        for (viewId in listOf(R.id.st_today_goal_value, R.id.st_today_tasks_value)) views.setTextColor(viewId, foreground)
        for (viewId in listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label)) views.setTextColor(viewId, secondary)
        // Measure metric width as well as height: tall, narrow widgets must still show the whole percentage.
        val metricWidth = if (compact) (width - 28) / 2 else if (stacked) width - 44 else (width - 32) / 2 - 20
        val metricSize = fittingAmountSize(context, percent, metricWidth, if (compact) 17f else 26f) ?: 12f
        views.setTextViewTextSize(R.id.st_today_goal_value, TypedValue.COMPLEX_UNIT_SP, metricSize)
        views.setTextViewTextSize(R.id.st_today_tasks_value, TypedValue.COMPLEX_UNIT_SP,
            fittingAmountSize(context, tasks, metricWidth, if (compact) 17f else 26f) ?: 12f)
        if (compact) {
            // Reapplication must restore labels that a previous short host hid.
            views.setViewVisibility(R.id.st_today_goal_label, View.VISIBLE)
            views.setViewVisibility(R.id.st_today_tasks_label, View.VISIBLE)
            if (!todayPanelsFit(context, views, width, height)) {
                views.setViewVisibility(R.id.st_today_goal_label, View.GONE)
                views.setViewVisibility(R.id.st_today_tasks_label, View.GONE)
            }
            return views
        }
        views.setTextColor(R.id.st_brand, secondary)
        views.setViewVisibility(R.id.st_cover, View.GONE)
        views.setImageViewResource(R.id.st_cover, 0)
        if (full && w >= 250 && h >= 270) cover(context, views, data)
        views.removeAllViews(R.id.st_actions)
        val actions = w >= 230 && h >= 260
        views.setViewVisibility(R.id.st_actions, if (actions) View.VISIBLE else View.GONE)
        if (actions) {
            if (goal?.optBoolean("canSave") == true) button(context, views, id, "Save", "save")
            button(context, views, id, "Planner", "planner")
            if (w >= 300 && h >= 360) button(context, views, id, "Coach", "coach")
        }
        val stamp = data?.optLong("confirmedAt", 0) ?: 0
        views.setViewVisibility(R.id.st_updated, if (h >= 330) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.st_updated, if (data?.optBoolean("cached") == true || stamp == 0L)
            "Saved snapshot · open app to sync" else "Updated ${SimpleDateFormat("MMM d, HH:mm", Locale.getDefault()).format(Date(stamp))}")
        views.setTextColor(R.id.st_updated, secondary)
        views.setTextViewText(R.id.st_today_goal_title, goalTitle)
        views.setTextViewText(R.id.st_today_tasks_title, taskTitle)
        views.setTextColor(R.id.st_today_goal_title, secondary)
        views.setTextColor(R.id.st_today_tasks_title, secondary)
        for (viewId in listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label, R.id.st_today_goal_title, R.id.st_today_tasks_title)) {
            views.setViewVisibility(viewId, View.VISIBLE)
        }
        for (panel in listOf(R.id.st_today_goal, R.id.st_today_tasks)) {
            views.setInt(panel, "setBackgroundResource", if (dark) R.drawable.st_widget_today_panel_dark else R.drawable.st_widget_today_panel)
        }
        for ((progressId, value) in listOf(R.id.st_today_goal_progress to goal?.optInt("progress"), R.id.st_today_tasks_progress to planner?.optInt("progress"))) {
            views.setViewVisibility(progressId, if (value == null) View.GONE else View.VISIBLE)
            views.setProgressBar(progressId, 1000, (value ?: 0).coerceIn(0, 1000), false)
        }
        val saved = goal?.optString("saved").orEmpty()
        val amountSize = fittingAmountSize(context, saved, metricWidth, 14f)
        val showAmount = full && saved.isNotBlank() && amountSize != null
        views.setViewVisibility(R.id.st_today_goal_amount, if (showAmount) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.st_today_goal_amount, if (showAmount) saved else "")
        views.setTextColor(R.id.st_today_goal_amount, secondary)
        val next = if (full && config?.optBoolean("showTaskTitles") == true) planner?.optJSONArray("tasks")?.optJSONObject(0) else null
        views.setViewVisibility(R.id.st_today_next_task, if (next == null) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.st_today_next_task, next?.let { "Next · ${it.optString("title")}" } ?: "")
        views.setTextColor(R.id.st_today_next_task, foreground)
        if (next != null) views.setOnClickPendingIntent(R.id.st_today_next_task, action(context, id, "task", taskId = next.optString("id")))
        // Both summaries are essential. Trim secondary rows together before either
        // panel can overflow at an intermediate launcher size or larger font scale.
        for (optional in listOf(
            listOf(R.id.st_today_goal_amount, R.id.st_today_next_task),
            listOf(R.id.st_today_goal_progress, R.id.st_today_tasks_progress),
            listOf(R.id.st_today_goal_title, R.id.st_today_tasks_title),
            listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label),
        )) {
            if (todayPanelsFit(context, views, width, height)) break
            optional.forEach { views.setViewVisibility(it, View.GONE) }
        }
        return views
    }
    private fun cover(context: Context, views: RemoteViews, data: JSONObject?): Boolean {
        val encoded = data?.optString("thumbnail")
        if (!encoded.isNullOrEmpty() && encoded.length <= 20000) {
            try {
                val bytes = Base64.decode(encoded, Base64.DEFAULT)
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                if (options.outWidth in 1..128 && options.outHeight in 1..128) {
                    views.setImageViewBitmap(R.id.st_cover, BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
                    views.setViewVisibility(R.id.st_cover, View.VISIBLE)
                    return true
                }
            } catch (_: Exception) { /* Brand icon remains the fallback. */ }
        }
        return false
    }
    private fun todayPanelsFit(context: Context, views: RemoteViews, width: Float, height: Float): Boolean {
        val root = views.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
        root.layout(0, 0, root.measuredWidth, root.measuredHeight)
        return listOf(R.id.st_today_goal, R.id.st_today_tasks).all {
            val panel = root.findViewById<View>(it)
            val allocated = panel.height
            panel.measure(View.MeasureSpec.makeMeasureSpec(panel.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
            panel.measuredHeight <= allocated
        }
    }
    private fun bodyHeight(context: Context, views: RemoteViews, width: Float, height: Float): Int {
        val root = views.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
        root.layout(0, 0, root.measuredWidth, root.measuredHeight)
        return root.findViewById<View>(R.id.st_body).height.coerceAtLeast(0)
    }
    private fun text(context: Context, value: String, sp: Float, color: Int, money: Boolean = false): RemoteViews =
        RemoteViews(context.packageName, if (money) R.layout.st_widget_amount else R.layout.st_widget_text).apply {
            setTextViewText(R.id.st_text, value)
            setTextViewTextSize(R.id.st_text, TypedValue.COMPLEX_UNIT_SP, sp)
            setTextColor(R.id.st_text, color)
        }
    private fun fittingAmountSize(context: Context, amount: String, widthDp: Float, preferredSp: Float): Float? {
        val paint = Paint().apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) }
        val available = widthDp * context.resources.displayMetrics.density
        var sp = preferredSp
        while (sp >= 14f) {
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, context.resources.displayMetrics)
            if (paint.measureText(amount) <= available) return sp
            sp -= 1f
        }
        return null // Show progress when an exact amount would be unreadable.
    }
    private fun progress(context: Context, value: Int, dark: Boolean) = RemoteViews(context.packageName, if (dark) R.layout.st_widget_progress else R.layout.st_widget_progress_light).apply {
        setProgressBar(R.id.st_progress, 1000, value.coerceIn(0, 1000), false)
    }
    private fun actionButton(context: Context, label: String, description: String, pendingIntent: PendingIntent) =
        RemoteViews(context.packageName, R.layout.st_widget_button).apply {
            setTextViewText(R.id.st_button, label)
            setContentDescription(R.id.st_button, description)
            setOnClickPendingIntent(R.id.st_button, pendingIntent)
        }
    private fun button(context: Context, views: RemoteViews, id: Int, label: String, destination: String) {
        views.addView(R.id.st_actions, actionButton(context, label, label, action(context, id, destination)))
    }
    private fun addTasks(context: Context, id: Int, planner: JSONObject, count: Int, dark: Boolean, add: (RemoteViews) -> Unit) {
        val tasks = planner.optJSONArray("tasks") ?: return
        for (index in 0 until count.coerceAtMost(tasks.length())) {
            val task = tasks.optJSONObject(index) ?: continue
            val row = RemoteViews(context.packageName, R.layout.st_widget_task)
            row.setTextViewText(R.id.st_task_title, task.optString("title"))
            row.setTextViewText(R.id.st_task_meta, listOf(task.optString("priority"), task.optString("time")).filter { it.isNotBlank() }.joinToString(" · "))
            row.setTextColor(R.id.st_task_title, if (dark) white else ink)
            row.setTextColor(R.id.st_task_meta, if (dark) mint else muted)
            row.setOnClickPendingIntent(R.id.st_task_row, action(context, id, "task", taskId = task.optString("id")))
            add(row)
        }
    }
}
