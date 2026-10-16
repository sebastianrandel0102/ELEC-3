package com.example.myproject.widgets

enum class WidgetSize { COMPACT, SMALL, MEDIUM, EXPANDED, EXTRA_LARGE }

object WidgetLayoutResolver {
    // Constraints are dp from the host, adjusted for text scaling, not grid cells.
    fun resolve(width: Float, height: Float, fontScale: Float): WidgetSize {
        val scale = if (fontScale.isFinite()) fontScale.coerceAtLeast(1f) else 1f
        val w = (if (width.isFinite() && width > 0) width else 110f) / scale
        val h = (if (height.isFinite() && height > 0) height else 56f) / scale
        return when {
            h < 120 || w < 125 && h < 190 -> WidgetSize.COMPACT
            w >= 250 && h >= 360 -> WidgetSize.EXTRA_LARGE
            w >= 250 && h >= 270 -> WidgetSize.EXPANDED
            w >= 250 && h >= 190 -> WidgetSize.MEDIUM
            else -> WidgetSize.SMALL
        }
    }

    fun todayStacked(width: Float, height: Float, scale: Float) =
        height / scale >= 190 && (width / scale < 200 || height > width)

    fun todayCompact(width: Float, height: Float, scale: Float) =
        !todayStacked(width, height, scale) && (height / scale < 120 || width / scale < 200)
}
