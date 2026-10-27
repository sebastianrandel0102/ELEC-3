package com.example.myproject.widgets

import android.content.Context
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RemoteViews
import com.example.myproject.R
import org.json.JSONObject

object QuickSaveRenderer {
    fun render(context: Context, id: Int, config: JSONObject, goal: JSONObject?, width: Float, height: Float): RemoteViews {
        val state = QuickSaveStore(context).state(id)
        val stage = state.optString("stage")
        val palette = WidgetVisualTokens.resolve(context, config, "quickSave")
        val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
        val fullPad = WidgetLayoutResolver.quickFullPad(width, height, scale)
        val decimal = if ((goal?.optInt("currencyDigits", 2) ?: 2) > 0) "." to "digit:." else "Cancel" to "cancel"
        val views = RemoteViews(context.packageName, R.layout.st_widget_quick_entry)
        views.setInt(android.R.id.background, "setBackgroundResource", palette.background)
        views.setTextViewText(R.id.st_quick_goal, goal?.optString("title") ?: "Quick Save")
        views.setContentDescription(R.id.st_quick_goal, "Quick Save. ${goal?.optString("title").orEmpty()}")
        val amount = state.optString("amount").ifEmpty { "0" }
        var displayAmount = "${config.optString("currency")} $amount"
        var amountSize = WidgetRenderer.fittingAmountSize(context, displayAmount, width - 24, 22f)
        if (amountSize == null) {
            displayAmount = amount
            amountSize = WidgetRenderer.fittingAmountSize(context, amount, width - 24, 18f)
            views.setTextViewText(R.id.st_quick_goal, "${config.optString("currency")} · ${goal?.optString("title") ?: "Quick Save"}")
        }
        views.setTextViewText(R.id.st_quick_amount, displayAmount)
        views.setInt(R.id.st_quick_amount, "setMaxLines", if (amountSize == null) 2 else 1)
        // Keep the original exact input in accessibility even if a large value is ellipsized.
        views.setContentDescription(R.id.st_quick_amount, "Amount ${config.optString("currency")} $amount")
        views.setTextViewTextSize(R.id.st_quick_amount, TypedValue.COMPLEX_UNIT_SP, amountSize ?: 14f)
        palette.textColor(context, views, R.id.st_quick_goal, palette.secondaryText)
        palette.textColor(context, views, R.id.st_quick_amount, palette.text)
        palette.textColor(context, views, R.id.st_quick_status, palette.secondaryText)
        val status = when (stage) {
            "review" -> "Review amount. Confirm to save."
            "pending" -> "Pending · waiting for network or save result"
            "retry" -> "Not confirmed. Retry the same save."
            "saved" -> "Saved · contribution confirmed"
            else -> state.optString("message").ifEmpty { if (fullPad) "Enter amount, then Review" else "More shows the next keys" }
        }
        views.setTextViewText(R.id.st_quick_status, status)
        views.setInt(R.id.st_quick_status, "setMaxLines", 1)
        views.setViewVisibility(R.id.st_quick_status, if (height / scale >= 205 || stage != "entry" || state.optString("message").isNotBlank()) View.VISIBLE else View.GONE)
        views.removeAllViews(R.id.st_quick_keys)
        fun row(vararg keys: Pair<String, String>) {
            val row = RemoteViews(context.packageName, R.layout.st_widget_quick_row)
            row.removeAllViews(R.id.st_action_row)
            keys.forEach { (label, control) ->
                val button = RemoteViews(context.packageName, R.layout.st_widget_button)
                button.setTextViewText(R.id.st_button, label)
                button.setTextViewTextSize(R.id.st_button, TypedValue.COMPLEX_UNIT_SP,
                    if (keys.size >= 3 && width / scale < 220) 12f else 14f)
                button.setContentDescription(R.id.st_button, when(control) { "back" -> "Backspace"; "page" -> "Next number keys"; else -> label })
                button.setInt(R.id.st_button, "setBackgroundResource", if (control in listOf("review", "confirm")) palette.actionBackground else palette.secondaryActionBackground)
                palette.textColor(context, button, R.id.st_button, if (control in listOf("review", "confirm")) palette.actionText else palette.text)
                button.setOnClickPendingIntent(R.id.st_button, QuickSaveActionReceiver.action(context, id, config.optLong("revision"), state.optString("flow"), control))
                row.addView(R.id.st_action_row, button)
            }
            views.addView(R.id.st_quick_keys, row)
        }
        when (stage) {
            "review" -> row("Cancel" to "cancel", "Confirm" to "confirm")
            "pending" -> Unit // No second Confirm while the immutable operation is unresolved.
            "retry" -> row("Retry" to "retry")
            "saved" -> row("New save" to "new")
            else -> {
                if (fullPad) {
                    val presets = config.optJSONArray("presets")
                    if (height / scale >= 410 && presets != null && presets.length() > 0 &&
                        (0 until presets.length()).all { WidgetRenderer.fittingAmountSize(context, presets.optString(it), (width - 24) / presets.length() - 12, 14f) != null }) {
                        row(*(0 until presets.length()).map { presets.optString(it) to "preset:$it" }.toTypedArray())
                    }
                    row("1" to "digit:1", "2" to "digit:2", "3" to "digit:3")
                    row("4" to "digit:4", "5" to "digit:5", "6" to "digit:6")
                    row("7" to "digit:7", "8" to "digit:8", "9" to "digit:9")
                    row(decimal, "0" to "digit:0", "Clear" to "clear")
                } else when (state.optInt("page")) {
                    0 -> row("1" to "digit:1", "2" to "digit:2", "3" to "digit:3")
                    1 -> row("4" to "digit:4", "5" to "digit:5", "6" to "digit:6")
                    2 -> row("7" to "digit:7", "8" to "digit:8", "9" to "digit:9")
                    3 -> row(decimal, "0" to "digit:0", "Clear" to "clear")
                    else -> {
                        val presets = config.optJSONArray("presets")
                        if (presets != null) row(*(0 until presets.length().coerceAtMost(3)).map { presets.optString(it) to "preset:$it" }.toTypedArray())
                        else row(decimal, "0" to "digit:0", "Clear" to "clear")
                    }
                }
                if (fullPad) row("Back" to "back", "Cancel" to "cancel", "Review" to "review")
                else row("More" to "page", "Back" to "back", "Review" to "review")
            }
        }
        run {
            // Measure one complete native tree, rather than estimating text
            // heights or repeatedly inflating every row. Host font fallback can
            // consume the keypad's space even at the same reported sp scale.
            val root = views.apply(context, FrameLayout(context))
            val density = context.resources.displayMetrics.density
            root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
            root.layout(0, 0, root.measuredWidth, root.measuredHeight)
            val keys = root.findViewById<LinearLayout>(R.id.st_quick_keys)
            val overflow = (0 until keys.childCount).any { keys.getChildAt(it).top < 0 } ||
                root.findViewById<View>(R.id.st_quick_status).bottom > root.height - root.paddingBottom
            if (overflow) {
                views.setViewVisibility(if (stage in listOf("entry", "review")) R.id.st_quick_status else R.id.st_quick_goal, View.GONE)
            }
        }
        return views
    }
}
