package com.example.myproject.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetLayoutResolverTest {
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
