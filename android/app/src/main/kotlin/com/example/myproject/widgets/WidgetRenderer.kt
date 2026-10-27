package com.example.myproject.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
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
    fun updateAll(context: Context) { WidgetStore(context).installed().keys.forEach { update(context, it) } }
    fun update(context: Context, id: Int, hostOptions: Bundle? = null) {
        val manager = AppWidgetManager.getInstance(context)
        val store = WidgetStore(context)
        val type = store.installed()[id] ?: return
        val options = hostOptions ?: manager.getAppWidgetOptions(id)
        val config = store.config(id)
        val snapshot = store.snapshot(id)
        val views = if (Build.VERSION.SDK_INT >= 31) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                RemoteViews(sizes.filter { it.width.isFinite() && it.height.isFinite() && it.width > 0 && it.height > 0 }.distinct().take(16).associateWith {
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
        if (!width.isFinite() || width <= 0 || !height.isFinite() || height <= 0) {
            return render(context, id, type, config, data, if (width.isFinite() && width > 0) width else 110f,
                if (height.isFinite() && height > 0) height else 56f)
        }
        val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        val size = WidgetLayoutResolver.resolve(width, height, scale)
        val compact = size == WidgetSize.COMPACT
        val w = width / scale
        val h = height / scale
        val palette = WidgetVisualTokens.resolve(context, config, type)
        val typography = WidgetTypography(context)
        val dark = palette.dark
        val foreground = palette.text
        val secondary = palette.secondaryText
        val full = config?.optString("privacy") == "full"
        val wideCompact = compact && WidgetLayoutResolver.composition(width, height, scale) == WidgetComposition.MEDIUM_SHORT && h >= 55
        val views = RemoteViews(context.packageName, if (wideCompact) R.layout.st_widget_wide else if (compact) R.layout.st_widget_compact else R.layout.st_widget)
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
        val background = palette.background
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
        val quickStage = if (type == "quickSave") QuickSaveStore(context).state(id).optString("stage") else ""
        if (type == "quickSave" && config != null && full && WidgetLayoutResolver.quickEntry(width, height, scale) &&
            (neutral == null && goal?.optBoolean("canSave") == true || quickStage in listOf("pending", "retry", "saved"))) {
            return QuickSaveRenderer.render(context, id, config, goal, width, height)
        }
        val dateValid = data?.optString("day") == SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()) &&
            data.optInt("timezoneOffsetMinutes") == TimeZone.getDefault().getOffset(now) / 60000
        val planner = if (dateValid) data.optJSONObject("planner")?.takeIf { it.optString("state") == "ready" } else null
        if (type == "today" && neutral == null) {
            return today(context, id, config, data, goal, planner, width, height, dark, background)
        }
        if (compact) {
            if (!wideCompact) {
                val show = neutral == null && type == "goal" && h >= 85
                views.setViewVisibility(R.id.st_compact_progress, if (show && !dark) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.st_compact_progress_dark, if (show && dark) View.VISIBLE else View.GONE)
                for (progressId in listOf(R.id.st_compact_progress, R.id.st_compact_progress_dark)) {
                    palette.progress(context, views, progressId)
                    views.setProgressBar(progressId, 1000, goal?.optInt("progress") ?: 0, false)
                }
            }
            if (wideCompact) {
                val value = if (type == "goal") goal?.optInt("progress") else if (type == "planner") planner?.optInt("progress") else null
                views.setViewVisibility(R.id.st_wide_progress, if (h >= 70 && neutral == null && value != null && !dark) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.st_wide_progress_dark, if (h >= 70 && neutral == null && value != null && dark) View.VISIBLE else View.GONE)
                palette.progress(context, views, R.id.st_wide_progress)
                palette.progress(context, views, R.id.st_wide_progress_dark)
                views.setProgressBar(R.id.st_wide_progress, 1000, value ?: 0, false)
                views.setProgressBar(R.id.st_wide_progress_dark, 1000, value ?: 0, false)
            }
            val title = if (neutral != null) "SaveTrack" else when (type) { "planner" -> SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date()); "quickSave" -> "Quick Save"; "today" -> "Saved · tasks"; else -> if (full) goal?.optString("title") ?: "SaveTrack" else "Savings goal" }
            var value = if (neutral != null) when (neutral) {
                "Sign in to SaveTrack" -> "Sign in"
                "Open SaveTrack to refresh" -> "Refresh"
                "Open SaveTrack" -> "Open app"
                else -> "Set up"
            } else when (type) {
                "planner" -> if (full && config?.optBoolean("showTaskTitles") == true && h >= 80)
                    planner?.optJSONArray("tasks")?.optJSONObject(0)?.let { task ->
                        listOf(task.optString("time"), task.optString("title")).filter { it.isNotBlank() }.joinToString(" · ")
                    } ?: planner?.let { "${it.optInt("remaining")} left" } ?: "Refresh"
                    else planner?.let { if (w < 140) it.optInt("remaining").toString() else "${it.optInt("remaining")} left" } ?: "Refresh"
                "quickSave" -> if (w < 160) "Add" else "Add Savings"
                "today" -> "${goal?.let { "${it.optInt("percent")}%" } ?: "—"} · ${planner?.optInt("remaining")?.toString() ?: "—"}"
                else -> if (full && goal != null && w >= 150 && h >= 70 &&
                    fittingAmountSize(context, goal.optString("saved"), width - 24, 18f) != null)
                    goal.optString("saved") else "${goal?.optInt("percent") ?: 0}%"
            }
            palette.icon(context, views, R.id.st_compact_logo)
            var showLogo = false
            val showTitle = neutral == null && h >= (if (wideCompact) 55 else 65)
            val labelHeight = if (showTitle && !wideCompact) 12 * scale * 1.3f else 0f
            val preferredSize = minOf(if (neutral != null) 14f else 18f, (height - 24 - labelHeight) / (scale * 1.3f)).coerceAtLeast(11f)
            var valueSize = fittingAmountSize(context, value, width - (if (showLogo) 54 else 24), preferredSize, 11f)
            if (valueSize == null) {
                showLogo = false
                valueSize = fittingAmountSize(context, value, width - 24, preferredSize, 11f)
            }
            if (valueSize == null && type != "planner") value = "Open"
            views.setViewVisibility(R.id.st_compact_logo, if (showLogo) View.VISIBLE else View.GONE)
            views.setContentDescription(android.R.id.background, "$title. $value")
            views.setTextViewText(R.id.st_compact_title, title)
            views.setTextViewText(R.id.st_compact_value, value)
            palette.textColor(context, views, R.id.st_compact_title, secondary)
            palette.textColor(context, views, R.id.st_compact_value, foreground)
            views.setViewVisibility(R.id.st_compact_title, if (showTitle) View.VISIBLE else View.GONE)
            views.setTextViewTextSize(R.id.st_compact_value, TypedValue.COMPLEX_UNIT_SP, valueSize ?: 14f)
            return views
        }
        palette.textColor(context, views, R.id.st_brand, secondary)
        palette.icon(context, views, R.id.st_brand_icon)
        views.setTextViewText(R.id.st_brand, if (w >= 230) when (type) {
            "goal" -> "SAVETRACK · SAVINGS"
            "planner" -> "SAVETRACK · TODAY'S FOCUS"
            "quickSave" -> "SAVETRACK · QUICK SAVE"
            else -> "SAVETRACK"
        } else if (w < 150) when (type) { "goal" -> "GOAL"; "planner" -> "TODAY"; "quickSave" -> "SAVE"; else -> "TODAY" } else "SAVETRACK")
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
        fun addText(text: String, sp: Float = 14f, color: Int = foreground, money: Boolean = false, lines: Int = 1, container: Int = R.id.st_body) {
            val row = text(context, text, sp, color, money, palette)
            if (!money) row.setInt(R.id.st_text, "setMaxLines", lines)
            if (container == R.id.st_body) addBody(row) else views.addView(container, row)
        }
        if (neutral != null) {
            addText(neutral, 20f)
            if (h >= 160) addText("Tap to open SaveTrack", 13f, secondary)
            return views
        }
        val actionHeight = if (type == "planner") 260 else 210
        val actions = size >= WidgetSize.MEDIUM && h >= actionHeight || type == "quickSave" && h >= 165
        val footer = h >= 310
        views.setViewVisibility(R.id.st_actions, if (actions) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.st_updated, if (footer) View.VISIBLE else View.GONE)
        if (footer) {
            val stamp = data?.optLong("confirmedAt", 0) ?: 0
            views.setTextViewText(R.id.st_updated, if (data?.optBoolean("cached") == true || stamp == 0L)
                "Saved snapshot · open app to sync" else "Updated ${SimpleDateFormat("MMM d, HH:mm", Locale.getDefault()).format(Date(stamp))}")
            palette.textColor(context, views, R.id.st_updated, secondary)
        }
        var budget = h - 48 - (if (actions) 56 else 0) - (if (footer) 24 else 0)
        if (full && size >= WidgetSize.EXPANDED && cover(context, views, data)) budget -= 12
        // Measure the actual native header/footer and row heights. Font fallback,
        // currency glyphs and host text scaling can exceed estimated sp budgets.
        availableBodyPixels = bodyHeight(context, views, width, height)
        fun goalSummary(limit: Float) {
            if (goal == null) { addText("Choose a savings goal", 16f); return }
            addText(if (full) goal.optString("title") else "Savings goal", 15f, lines = if (h >= 270) 2 else 1)
            val amountSize = fittingAmountSize(context, goal.optString("saved"), width - 24f, if (w >= 250) typography.display else 22f)
            if (full && limit >= 110 && w >= 180 && amountSize != null) {
                addText(goal.optString("saved"), amountSize, money = true)
                addText("of ${goal.optString("target")} · ${goal.optInt("percent")}%", 12f, secondary, money = true)
            } else {
                val value = "${goal.optInt("percent")}%"
                addText(value, fittingAmountSize(context, value, width - 24, typography.metric) ?: typography.compact)
            }
            addBody(progress(context, goal.optInt("progress"), palette))
            if (limit >= 100) addText(goal.optString("status"), 12f,
                if (goal.optString("status").contains("Overdue", true)) palette.warning else secondary)
            if (full && limit >= 145 && w >= 180) {
                addBody(miniMetrics(context, goal, palette, w >= 260))
                if (w < 260 && goal.has("deadline")) addText("Deadline · ${goal.optString("deadline")}", 12f, secondary)
            } else if (full && limit >= 145) {
                // Never split a narrow financial value into ambiguous digit groups.
                for ((label, value) in listOf("SAVED" to goal.optString("saved"), "REMAINING" to goal.optString("remaining"))) {
                    if (fittingAmountSize(context, value, width - 24, 16f) != null) {
                        addText(label, 11f, secondary)
                        addText(value, 14f, money = true)
                    }
                }
                val deadline = goal.optString("deadline")
                if (deadline.isNotBlank() && fittingAmountSize(context, deadline, width - 24, 14f) != null) {
                    addText("DEADLINE", 11f, secondary)
                    addText(deadline, 14f)
                }
            }
        }
        when (type) {
            "goal" -> {
                goalSummary(budget)
                if (actions) {
                    if (goal?.optBoolean("canSave") == true) button(context, views, id, "Add Savings", "save", palette)
                    if (w >= 280) button(context, views, id, "Open Goal", "goal", palette, false)
                }
            }
            "planner" -> {
                addText(SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date()), 12f, secondary)
                if (planner == null) addText("Open Planner to refresh", 18f)
                else {
                    val total = planner.optInt("total")
                    if (total == 0) {
                        val empty = RemoteViews(context.packageName, R.layout.st_widget_empty)
                        empty.setTextViewText(R.id.st_text, "All clear today")
                        palette.textColor(context, empty, R.id.st_text, foreground)
                        palette.icon(context, empty, R.id.st_empty_icon)
                        addBody(empty)
                    } else addText("${planner.optInt("done")} / $total complete", typography.section)
                    budget -= 50
                    if (budget >= 35) {
                        val left = planner.optInt("remaining")
                        addText(if (total == 0) "No tasks scheduled." else "$left ${if (left == 1) "task" else "tasks"} left", 12f, secondary)
                        addBody(progress(context, planner.optInt("progress"), palette))
                        budget -= 32
                    }
                    val rows = ((budget - 4) / 56).toInt().coerceIn(0, 5)
                    if (full && config.optBoolean("showTaskTitles") == true) addTasks(context, id, planner, rows, palette, ::addBody)
                }
                if (actions) button(context, views, id, "Open Planner", "planner", palette)
            }
            "quickSave" -> {
                addText("Quick Save", typography.headline)
                addText(goal?.let { (if (full) "${it.optString("currency")} · " else "") + (if (full) it.optString("title") else "Savings goal") } ?: "Choose a goal", 13f, secondary)
                budget -= 50
                val presets = goal?.optJSONArray("presets")
                val rawPresets = config?.optJSONArray("presets")
                val labels = if (presets == null) emptyList() else (0 until presets.length().coerceAtMost(3)).map {
                    "+${presets.optString(it).removePrefix("${goal?.optString("currency")} ")}"
                }
                val labelWidth = (width - 24) / labels.size.coerceAtLeast(1) - 12
                val labelPaint = Paint().apply {
                    typeface = Typeface.DEFAULT_BOLD
                    textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 13f, context.resources.displayMetrics)
                }
                val labelsFit = labels.all { labelPaint.measureText(it) <= labelWidth * context.resources.displayMetrics.density }
                if (full && goal?.optBoolean("canSave") == true && w >= 250 && budget >= 55 && presets != null && rawPresets != null && labels.isNotEmpty() && labelsFit) {
                    val row = RemoteViews(context.packageName, R.layout.st_widget_actions)
                    row.removeAllViews(R.id.st_action_row)
                    for (index in 0 until presets.length().coerceAtMost(3)) {
                        val label = labels[index]
                        val button = actionButton(context, label, presets.optString(index), action(context, id, "save", index), palette, false)
                        row.addView(R.id.st_action_row, button)
                    }
                    addBody(row)
                    budget -= 55
                }
                if (budget >= 40) addText("Choose an amount. Confirm in SaveTrack.", 12f, secondary, money = true)
                if (h >= 270 && goal != null) {
                    addText("${goal.optInt("percent")}% of your goal", 12f, secondary)
                    addBody(progress(context, goal.optInt("progress"), palette))
                }
                if (actions) button(context, views, id, if (goal?.optBoolean("canSave") == true) "+ Add Savings" else "Open Goal", if (goal?.optBoolean("canSave") == true) "save" else "goal", palette)
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
        val stacked = WidgetLayoutResolver.todayStacked(width, height, scale)
        val compact = WidgetLayoutResolver.todayCompact(width, height, scale)
        val layout = if (compact) R.layout.st_widget_today_compact else if (stacked) R.layout.st_widget_today_stacked else R.layout.st_widget_today
        val views = RemoteViews(context.packageName, layout)
        val palette = WidgetVisualTokens.resolve(context, config, "today")
        val typography = WidgetTypography(context)
        val foreground = palette.text
        val secondary = palette.secondaryText
        val full = config?.optString("privacy") == "full"
        val percent = goal?.let { "${it.optInt("percent")}%" } ?: "—"
        val remaining = planner?.optInt("remaining")?.coerceAtLeast(0)
        val tasks = if (planner == null) "—" else if (compact) remaining.toString() else "${planner.optInt("done")} / ${planner.optInt("total")}"
        val goalTitle = if (goal == null) "Choose a goal" else if (full) goal.optString("title") else "Goal progress"
        val taskTitle = when {
            planner == null -> "Open to refresh"
            planner.optInt("total") == 0 -> "No tasks today"
            remaining == 0 -> "All tasks done"
            remaining == 1 -> "1 task left"
            else -> "$remaining tasks left"
        }
        views.setInt(android.R.id.background, "setBackgroundResource", background)
        views.setOnClickPendingIntent(android.R.id.background, action(context, id, "dashboard"))
        views.setOnClickPendingIntent(R.id.st_today_goal, if (compact) null else action(context, id, if (goal == null) "configure" else "goal"))
        views.setOnClickPendingIntent(R.id.st_today_tasks, if (compact) null else action(context, id, "planner"))
        views.setContentDescription(R.id.st_today_goal, "Savings. $goalTitle. $percent")
        views.setContentDescription(R.id.st_today_tasks, if (planner == null) "Today's tasks. Open Planner to refresh" else
            "Today's tasks. $tasks $taskTitle. ${planner.optInt("done")} of ${planner.optInt("total")} completed")
        views.setTextViewText(R.id.st_today_goal_value, percent)
        views.setTextViewText(R.id.st_today_tasks_value, tasks)
        for (viewId in listOf(R.id.st_today_goal_value, R.id.st_today_tasks_value)) palette.textColor(context, views, viewId, foreground)
        for (viewId in listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label)) palette.textColor(context, views, viewId, secondary)
        // Measure metric width as well as height: tall, narrow widgets must still show the whole percentage.
        val metricWidth = if (compact) (width - 28) / 2 else if (stacked) width - 48 else (width - 32) / 2 - 24
        if (compact && fittingAmountSize(context, percent, metricWidth, 17f) == null) {
            // At extreme text scale, one readable summary beats two clipped columns.
            val combined = "$percent · $tasks"
            val font = fittingAmountSize(context, combined, width - 28, 17f, 11f)
            return RemoteViews(context.packageName, R.layout.st_widget_compact).apply {
                setInt(android.R.id.background, "setBackgroundResource", background)
                setViewVisibility(R.id.st_compact_logo, View.GONE)
                setViewVisibility(R.id.st_compact_title, if (h >= 55) View.VISIBLE else View.GONE)
                setTextViewText(R.id.st_compact_title, "Today · tasks")
                setTextViewText(R.id.st_compact_value, if (font == null) "Open" else combined)
                setTextViewTextSize(R.id.st_compact_value, TypedValue.COMPLEX_UNIT_SP, font ?: 14f)
                palette.textColor(context, this, R.id.st_compact_title, secondary)
                palette.textColor(context, this, R.id.st_compact_value, foreground)
                setContentDescription(android.R.id.background, "Savings $percent. $remaining tasks left. Open SaveTrack.")
                setOnClickPendingIntent(android.R.id.background, action(context, id, "dashboard"))
            }
        }
        val metricSize = fittingAmountSize(context, percent, metricWidth, if (compact) typography.compact - 1 else typography.metric) ?: 12f
        views.setTextViewTextSize(R.id.st_today_goal_value, TypedValue.COMPLEX_UNIT_SP, metricSize)
        views.setTextViewTextSize(R.id.st_today_tasks_value, TypedValue.COMPLEX_UNIT_SP,
            fittingAmountSize(context, tasks, metricWidth, if (compact) typography.compact - 1 else typography.metric) ?: 12f)
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
        palette.textColor(context, views, R.id.st_brand, secondary)
        palette.icon(context, views, R.id.st_brand_icon)
        views.setTextViewText(R.id.st_brand, if (w < 150) "TODAY" else "SAVETRACK · TODAY")
        views.setTextViewText(R.id.st_today_tasks_label, if (w < 180) "Tasks" else "Today's focus")
        views.setViewVisibility(R.id.st_cover, View.GONE)
        views.setImageViewResource(R.id.st_cover, 0)
        if (full && w >= 250 && h >= 270) cover(context, views, data)
        views.removeAllViews(R.id.st_actions)
        val actions = w >= 230 && h >= 390
        views.setViewVisibility(R.id.st_actions, if (actions) View.VISIBLE else View.GONE)
        if (actions) {
            if (goal?.optBoolean("canSave") == true) button(context, views, id, "Save", "save", palette)
            button(context, views, id, "Planner", "planner", palette, false)
            if (w >= 300 && h >= 360) button(context, views, id, "AI Coach", "coach", palette, false)
        }
        val stamp = data?.optLong("confirmedAt", 0) ?: 0
        views.setViewVisibility(R.id.st_updated, if (h >= 390 || h >= 330 && data?.optBoolean("cached") == true) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.st_updated, if (data?.optBoolean("cached") == true || stamp == 0L)
            "Saved snapshot · open app to sync" else "Updated ${SimpleDateFormat("MMM d, HH:mm", Locale.getDefault()).format(Date(stamp))}")
        palette.textColor(context, views, R.id.st_updated, secondary)
        views.setTextViewText(R.id.st_today_goal_title, goalTitle)
        views.setTextViewText(R.id.st_today_tasks_title, taskTitle)
        palette.textColor(context, views, R.id.st_today_goal_title, secondary)
        palette.textColor(context, views, R.id.st_today_tasks_title, secondary)
        for (viewId in listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label, R.id.st_today_goal_title, R.id.st_today_tasks_title)) {
            views.setViewVisibility(viewId, View.VISIBLE)
        }
        for (panel in listOf(R.id.st_today_goal, R.id.st_today_tasks)) {
            views.setInt(panel, "setBackgroundResource", if (panel == R.id.st_today_tasks) palette.secondarySurface else palette.surface)
        }
        for ((progressId, nightId, value) in listOf(Triple(R.id.st_today_goal_progress, R.id.st_today_goal_progress_dark, goal?.optInt("progress")),
            Triple(R.id.st_today_tasks_progress, R.id.st_today_tasks_progress_dark, planner?.optInt("progress")))) {
            views.setViewVisibility(progressId, if (value != null && !dark) View.VISIBLE else View.GONE)
            views.setViewVisibility(nightId, if (value != null && dark) View.VISIBLE else View.GONE)
            palette.progress(context, views, progressId)
            palette.progress(context, views, nightId)
            views.setProgressBar(progressId, 1000, (value ?: 0).coerceIn(0, 1000), false)
            views.setProgressBar(nightId, 1000, (value ?: 0).coerceIn(0, 1000), false)
        }
        val saved = goal?.optString("saved").orEmpty()
        val amountSize = fittingAmountSize(context, saved, metricWidth, 14f)
        val showAmount = full && saved.isNotBlank() && amountSize != null
        views.setViewVisibility(R.id.st_today_goal_amount, if (showAmount) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.st_today_goal_amount, if (showAmount) saved else "")
        palette.textColor(context, views, R.id.st_today_goal_amount, secondary)
        val remainder = goal?.optString("remaining").orEmpty().let { if (it.isBlank()) "" else "$it remaining" }
        val showRemaining = full && h >= 270 && remainder.isNotBlank() && fittingAmountSize(context, remainder, metricWidth, 14f) != null
        views.setViewVisibility(R.id.st_today_goal_remaining, if (showRemaining) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.st_today_goal_remaining, if (showRemaining) remainder else "")
        palette.textColor(context, views, R.id.st_today_goal_remaining, secondary)
        val next = if (full && config.optBoolean("showTaskTitles") == true) planner?.optJSONArray("tasks")?.optJSONObject(0) else null
        views.setViewVisibility(R.id.st_today_next_task, if (next == null) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.st_today_next_task, next?.let { "Next · ${it.optString("title")}" } ?: "")
        palette.textColor(context, views, R.id.st_today_next_task, foreground)
        if (next != null) views.setOnClickPendingIntent(R.id.st_today_next_task, action(context, id, "task", taskId = next.optString("id")))
        if (next != null) views.setViewVisibility(R.id.st_today_tasks_title, View.GONE)
        // Both summaries are essential. Trim secondary rows together before either
        // panel can overflow at an intermediate launcher size or larger font scale.
        for (optional in listOf(
            listOf(R.id.st_today_goal_remaining),
            listOf(R.id.st_today_goal_amount, R.id.st_today_next_task),
            listOf(R.id.st_today_goal_progress, R.id.st_today_tasks_progress, R.id.st_today_goal_progress_dark, R.id.st_today_tasks_progress_dark),
            listOf(R.id.st_today_goal_title, R.id.st_today_tasks_title),
            listOf(R.id.st_today_goal_label, R.id.st_today_tasks_label),
        )) {
            if (todayPanelsFit(context, views, width, height)) break
            optional.forEach { views.setViewVisibility(it, View.GONE) }
            if (R.id.st_today_next_task in optional) views.setViewVisibility(R.id.st_today_tasks_title, View.VISIBLE)
        }
        return views
    }
    private fun miniMetrics(context: Context, goal: JSONObject, palette: WidgetVisualTokens, paired: Boolean): RemoteViews {
        return RemoteViews(context.packageName, if (paired) R.layout.st_widget_mini_metrics_pair else R.layout.st_widget_mini_metrics).apply {
            setTextViewText(R.id.st_mini_label, "REMAINING")
            setTextViewText(R.id.st_mini_value, goal.optString("remaining"))
            palette.textColor(context, this, R.id.st_mini_label, palette.secondaryText)
            palette.textColor(context, this, R.id.st_mini_value, palette.text)
            setInt(if (paired) R.id.st_mini_first else R.id.st_mini_metrics, "setBackgroundResource", palette.secondarySurface)
            if (paired) {
                setInt(R.id.st_mini_second, "setBackgroundResource", palette.secondarySurface)
                setTextViewText(R.id.st_mini_second_value, goal.optString("deadline").ifBlank { "No deadline" })
                palette.textColor(context, this, R.id.st_mini_second_label, palette.secondaryText)
                palette.textColor(context, this, R.id.st_mini_second_value, palette.text)
            }
        }
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
    private fun text(context: Context, value: String, sp: Float, color: Int, money: Boolean = false, palette: WidgetVisualTokens): RemoteViews =
        RemoteViews(context.packageName, if (money) R.layout.st_widget_amount else if (sp >= 20) R.layout.st_widget_metric else R.layout.st_widget_text).apply {
            setTextViewText(R.id.st_text, value)
            setTextViewTextSize(R.id.st_text, TypedValue.COMPLEX_UNIT_SP, sp)
            palette.textColor(context, this, R.id.st_text, color)
        }
    internal fun fittingAmountSize(context: Context, amount: String, widthDp: Float, preferredSp: Float, minimumSp: Float = 14f): Float? {
        val paint = Paint().apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) }
        val available = widthDp * context.resources.displayMetrics.density
        var sp = preferredSp
        while (sp >= minimumSp) {
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, context.resources.displayMetrics)
            if (paint.measureText(amount) <= available) return sp
            sp -= 1f
        }
        return null // Show progress when an exact amount would be unreadable.
    }
    private fun progress(context: Context, value: Int, palette: WidgetVisualTokens) = RemoteViews(context.packageName, palette.progressLayout).apply {
        palette.progress(context, this, R.id.st_progress)
        setProgressBar(R.id.st_progress, 1000, value.coerceIn(0, 1000), false)
    }
    private fun actionButton(context: Context, label: String, description: String, pendingIntent: PendingIntent, palette: WidgetVisualTokens, primary: Boolean = true) =
        RemoteViews(context.packageName, R.layout.st_widget_button).apply {
            setInt(R.id.st_button, "setBackgroundResource", if (primary) palette.actionBackground else palette.secondaryActionBackground)
            palette.textColor(context, this, R.id.st_button, if (primary) palette.actionText else palette.text)
            setTextViewText(R.id.st_button, label)
            setContentDescription(R.id.st_button, description)
            setOnClickPendingIntent(R.id.st_button, pendingIntent)
        }
    private fun button(context: Context, views: RemoteViews, id: Int, label: String, destination: String, palette: WidgetVisualTokens, primary: Boolean = true) {
        views.addView(R.id.st_actions, actionButton(context, label, label, action(context, id, destination), palette, primary))
    }
    private fun addTasks(context: Context, id: Int, planner: JSONObject, count: Int, palette: WidgetVisualTokens, add: (RemoteViews) -> Unit) {
        val tasks = planner.optJSONArray("tasks") ?: return
        for (index in 0 until count.coerceAtMost(tasks.length())) {
            val task = tasks.optJSONObject(index) ?: continue
            val row = RemoteViews(context.packageName, R.layout.st_widget_task)
            row.setTextViewText(R.id.st_task_title, task.optString("title"))
            row.setTextViewText(R.id.st_task_meta, listOf(task.optString("priority"), task.optString("time")).filter { it.isNotBlank() }.joinToString(" · "))
            row.setInt(R.id.st_task_row, "setBackgroundResource", palette.surface)
            palette.icon(context, row, R.id.st_task_icon)
            palette.textColor(context, row, R.id.st_task_title, palette.text)
            palette.textColor(context, row, R.id.st_task_meta, palette.secondaryText)
            row.setOnClickPendingIntent(R.id.st_task_row, action(context, id, "task", taskId = task.optString("id")))
            add(row)
        }
    }
}
