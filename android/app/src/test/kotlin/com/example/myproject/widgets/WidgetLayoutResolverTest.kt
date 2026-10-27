package com.example.myproject.widgets

import org.junit.Assert.*
import org.junit.Test

class WidgetLayoutResolverTest {
    @Test fun compositionBoundariesUseBothDimensions() {
        assertEquals(WidgetComposition.COMPACT_NARROW, WidgetLayoutResolver.composition(155f, 220f, 1f))
        assertEquals(WidgetComposition.COMPACT_STANDARD, WidgetLayoutResolver.composition(156f, 220f, 1f))
        assertEquals(WidgetComposition.MEDIUM_SHORT, WidgetLayoutResolver.composition(240f, 119f, 1f))
        assertEquals(WidgetComposition.COMPACT_STANDARD, WidgetLayoutResolver.composition(249f, 190f, 1f))
        assertEquals(WidgetComposition.COMPACT_STANDARD, WidgetLayoutResolver.composition(250f, 189f, 1f))
        assertEquals(WidgetComposition.MEDIUM_STANDARD, WidgetLayoutResolver.composition(250f, 190f, 1f))
        assertEquals(WidgetComposition.MEDIUM_STANDARD, WidgetLayoutResolver.composition(300f, 269f, 1f))
        assertEquals(WidgetComposition.EXPANDED, WidgetLayoutResolver.composition(300f, 270f, 1f))
        assertEquals(WidgetComposition.EXPANDED_WIDE, WidgetLayoutResolver.composition(360f, 270f, 1f))
        assertFalse(WidgetLayoutResolver.quickEntry(156f, 209f, 1f))
        assertTrue(WidgetLayoutResolver.quickEntry(156f, 210f, 1f))
        assertFalse(WidgetLayoutResolver.quickFullPad(240f, 359f, 1f))
        assertTrue(WidgetLayoutResolver.quickFullPad(240f, 360f, 1f))
        assertFalse(WidgetLayoutResolver.quickFullPad(240f, 360f, 1.5f))
    }
    @Test fun widthAndHeightBothDetermineContent() {
        assertEquals(WidgetSize.COMPACT, WidgetLayoutResolver.resolve(350f, 64f, 1f))
        assertEquals(WidgetSize.SMALL, WidgetLayoutResolver.resolve(150f, 350f, 1f))
        assertEquals(WidgetSize.MEDIUM, WidgetLayoutResolver.resolve(300f, 220f, 1f))
        assertEquals(WidgetSize.EXPANDED, WidgetLayoutResolver.resolve(300f, 300f, 1f))
        assertEquals(WidgetSize.EXTRA_LARGE, WidgetLayoutResolver.resolve(350f, 420f, 1f))
    }
    @Test fun largeTextReducesContentInsteadOfShrinkingType() {
        assertEquals(WidgetSize.SMALL, WidgetLayoutResolver.resolve(300f, 220f, 1.5f))
        assertEquals(WidgetSize.COMPACT, WidgetLayoutResolver.resolve(120f, 64f, 2f))
    }
    @Test fun invalidBoundsFallBackAndTallLargeTextRetainsUsefulContent() {
        assertEquals(WidgetSize.COMPACT, WidgetLayoutResolver.resolve(Float.NaN, -1f, Float.NaN))
        assertEquals(WidgetSize.SMALL, WidgetLayoutResolver.resolve(150f, 420f, 2f))
    }
}
