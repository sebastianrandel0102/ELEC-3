package com.example.myproject.widgets

enum class WidgetSize { COMPACT, SMALL, MEDIUM, EXPANDED, EXTRA_LARGE }
enum class WidgetComposition { COMPACT_NARROW, COMPACT_STANDARD, MEDIUM_SHORT, MEDIUM_STANDARD, EXPANDED, EXPANDED_WIDE }

object WidgetLayoutResolver {
    fun composition(width: Float, height: Float, fontScale: Float): WidgetComposition {
        val scale = if (fontScale.isFinite()) fontScale.coerceAtLeast(1f) else 1f
        val w = (if (width.isFinite() && width > 0) width else 110f) / scale
        val h = (if (height.isFinite() && height > 0) height else 56f) / scale
        return when {
            w >= 240 && h < 120 -> WidgetComposition.MEDIUM_SHORT
            w < 156 -> WidgetComposition.COMPACT_NARROW
            w < 250 || h < 190 -> WidgetComposition.COMPACT_STANDARD
            h < 270 -> WidgetComposition.MEDIUM_STANDARD
            w >= 360 -> WidgetComposition.EXPANDED_WIDE
            else -> WidgetComposition.EXPANDED
        }
    }
    fun quickEntry(width: Float, height: Float, scale: Float) = width / scale >= 156 && height / scale >= 210
    fun quickFullPad(width: Float, height: Float, scale: Float) = width / scale >= 240 && height / scale >= 360
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
