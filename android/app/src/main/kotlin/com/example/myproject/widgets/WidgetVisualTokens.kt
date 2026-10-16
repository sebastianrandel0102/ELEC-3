package com.example.myproject.widgets

import android.content.Context
import android.content.res.Configuration
import android.content.res.ColorStateList
import android.os.Build
import android.util.TypedValue
import android.widget.RemoteViews
import com.example.myproject.R
import org.json.JSONObject

/** Read unscaled sp values from the same resource scale used by the XML views. */
class WidgetTypography(context: Context) {
    val display = sp(context, R.dimen.st_widget_display)
    val metric = sp(context, R.dimen.st_widget_metric)
    val section = sp(context, R.dimen.st_widget_section)
    val headline = sp(context, R.dimen.st_widget_headline)
    val compact = sp(context, R.dimen.st_widget_compact_metric)
    private fun sp(context: Context, resource: Int): Float = TypedValue().let {
        context.resources.getValue(resource, it, true)
        TypedValue.complexToFloat(it.data)
    }
}

/** Presentation only. Stored preference and Android appearance remain separate. */
data class WidgetVisualTokens(
    val dark: Boolean,
    val background: Int,
    val surface: Int,
    val secondarySurface: Int,
    val text: Int,
    val secondaryText: Int,
    val accent: Int,
    val warning: Int,
    val actionBackground: Int,
    val actionText: Int,
    val secondaryActionBackground: Int,
    val progressLayout: Int,
    val progressDrawable: Int,
    val system: Boolean = false,
) {
    fun textColor(context: Context, views: RemoteViews, id: Int, color: Int) {
        if (system && Build.VERSION.SDK_INT >= 31) {
            val day = palette(context, false)
            val night = palette(context, true)
            val pair = when (color) {
                text -> day.text to night.text
                secondaryText -> day.secondaryText to night.secondaryText
                accent -> day.accent to night.accent
                warning -> day.warning to night.warning
                actionText -> day.actionText to night.actionText
                else -> color to color
            }
            views.setColorInt(id, "setTextColor", pair.first, pair.second)
        } else views.setTextColor(id, color)
    }
    fun icon(context: Context, views: RemoteViews, id: Int) {
        if (system && Build.VERSION.SDK_INT >= 31) views.setColorInt(id, "setColorFilter", palette(context, false).accent, palette(context, true).accent)
        else views.setInt(id, "setColorFilter", accent)
    }
    fun progress(context: Context, views: RemoteViews, id: Int) {
        if (system && Build.VERSION.SDK_INT >= 31) {
            views.setColorStateList(id, "setProgressTintList", ColorStateList.valueOf(context.getColor(R.color.st_day_accent)), ColorStateList.valueOf(context.getColor(R.color.st_night_accent)))
            views.setColorStateList(id, "setProgressBackgroundTintList", ColorStateList.valueOf(context.getColor(R.color.st_day_track)), ColorStateList.valueOf(context.getColor(R.color.st_night_track)))
        }
    }
    companion object {
        fun resolve(context: Context, config: JSONObject?, type: String): WidgetVisualTokens {
            val preference = config?.optString("theme")
            val dark = when (preference) {
                "emerald" -> true
                "mint", "white" -> false
                "system" -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
                else -> type != "planner"
            }
            return palette(context, dark).let {
                when (preference) {
                    "white" -> it.copy(background = R.drawable.st_widget_white)
                    "system" -> it.copy(system = true, background = R.drawable.st_widget_system,
                        surface = R.drawable.st_widget_system_surface, secondarySurface = R.drawable.st_widget_system_secondary,
                        actionBackground = R.drawable.st_widget_system_action, secondaryActionBackground = R.drawable.st_widget_system_secondary)
                    else -> it
                }
            }
        }
        fun palette(context: Context, dark: Boolean) = WidgetVisualTokens(
            dark,
            if (dark) R.drawable.st_widget_emerald else R.drawable.st_widget_mint,
            if (dark) R.drawable.st_widget_today_panel_dark else R.drawable.st_widget_today_panel,
            if (dark) R.drawable.st_widget_secondary_dark else R.drawable.st_widget_secondary_light,
            context.getColor(if (dark) R.color.st_night_text else R.color.st_day_text),
            context.getColor(if (dark) R.color.st_night_secondary_text else R.color.st_day_secondary_text),
            context.getColor(if (dark) R.color.st_night_accent else R.color.st_day_accent),
            context.getColor(if (dark) R.color.st_night_warning else R.color.st_day_warning),
            if (dark) R.drawable.st_widget_button_bg else R.drawable.st_widget_button_light,
            context.getColor(if (dark) R.color.st_night_action_text else R.color.st_day_action_text),
            if (dark) R.drawable.st_widget_button_secondary_dark else R.drawable.st_widget_button_secondary_light,
            if (dark) R.layout.st_widget_progress else R.layout.st_widget_progress_light,
            if (dark) R.drawable.st_widget_progress_track else R.drawable.st_widget_progress_track_light,
        )
    }
}
