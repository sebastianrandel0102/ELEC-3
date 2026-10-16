package com.example.myproject.widgets

enum class WidgetSize { COMPACT, SMALL, MEDIUM, EXPANDED, EXTRA_LARGE }

object WidgetLayoutResolver {
    // Constraints are dp from the host, adjusted for text scaling, not grid cells.
    fun resolve(width: Float, height: Float, fontScale: Float): WidgetSize {
        val scale = fontScale.coerceAtLeast(1f)
        val w = width / scale
        val h = height / scale
        return when {
            h < 110 || w < 125 -> WidgetSize.COMPACT
            w >= 250 && h >= 360 -> WidgetSize.EXTRA_LARGE
            w >= 250 && h >= 270 -> WidgetSize.EXPANDED
            w >= 250 && h >= 190 -> WidgetSize.MEDIUM
            else -> WidgetSize.SMALL
        }
    }
}
