package com.example.myproject.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import com.example.myproject.R
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.pow

/** Actual native pixels and text metrics; sample facts are restricted to tests. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [31])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WidgetAtelierRenderingTest {
    private lateinit var app: Context
    @Before fun setup() {
        app = RuntimeEnvironment.getApplication()
        WidgetStore(app).setSession("atelier-test")
    }
    private fun context(night: Boolean = false, scale: Float = 1f): Context = app.createConfigurationContext(
        Configuration(app.resources.configuration).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            fontScale = scale
        })
    private fun settings(type: String, theme: String = "mint", privacy: String = "full") = JSONObject()
        .put("type", type).put("theme", theme).put("privacy", privacy).put("showTaskTitles", true)
        .put("currency", "PHP").put("presets", JSONArray(listOf("50.00", "100.00", "500.00")))
    private fun facts() = JSONObject().put("state", "ready").put("updatedAt", System.currentTimeMillis())
        .put("confirmedAt", System.currentTimeMillis())
        .put("day", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
        .put("timezoneOffsetMinutes", TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000)
        .put("goal", JSONObject().put("title", "Motorcycle Fund").put("percent", 40).put("progress", 400)
            .put("saved", "PHP ₱12,000.00").put("target", "PHP ₱30,000.00").put("remaining", "PHP ₱18,000.00")
            .put("currency", "PHP").put("status", "Active").put("deadline", "2027-01-31").put("canSave", true)
            .put("presets", JSONArray(listOf("PHP ₱50.00", "PHP ₱100.00", "PHP ₱500.00"))))
        .put("planner", JSONObject().put("state", "ready").put("total", 3).put("done", 1).put("remaining", 2).put("progress", 333)
            .put("tasks", JSONArray().put(JSONObject().put("id", "task-1").put("title", "Finish school project").put("priority", "High").put("time", "14:00"))
                .put(JSONObject().put("id", "task-2").put("title", "Review study notes").put("priority", "Medium").put("time", "16:30"))))
    private fun measured(context: Context, remote: RemoteViews, width: Int, height: Int): View {
        val root = remote.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
        root.layout(0, 0, root.measuredWidth, root.measuredHeight)
        return root
    }
    private fun fits(view: View, message: String) {
        if (view.visibility != View.VISIBLE) return
        if (view is ViewGroup) for (index in 0 until view.childCount) {
            val child = view.getChildAt(index)
            if (child.visibility != View.VISIBLE) continue
            assertTrue("$message horizontal ${child.id}: ${child.left}..${child.right} / ${view.width}", child.left >= 0 && child.right <= view.width + 1)
            assertTrue("$message vertical ${child.id}: ${child.top}..${child.bottom} / ${view.height}", child.top >= 0 && child.bottom <= view.height + 1)
            fits(child, message)
        }
        if (view is TextView && view.id in listOf(R.id.st_today_goal_value, R.id.st_today_tasks_value)) {
            assertTrue("$message whole metric ${view.text}", view.paint.measureText(view.text.toString()) <= view.width + 1)
        }
    }
    private fun export(root: View, name: String) {
        System.getenv("SAVETRACK_WIDGET_PREVIEW_DIR")?.let { directory ->
            val file = File(directory, name)
            file.parentFile?.mkdirs()
            val bitmap = Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
            root.draw(Canvas(bitmap))
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }
    @Test fun allWidgetsRenderAcrossThemesAndShapes() {
        for (type in WidgetStore.providers.keys) for ((theme, night) in listOf("mint" to false, "emerald" to false, "white" to true, "system" to false, "system" to true)) {
            val context = context(night)
            for ((width, height) in listOf(140 to 80, 180 to 100, 180 to 210, 350 to 100, 300 to 220, 350 to 360, 150 to 420, 500 to 550)) {
                val root = measured(context, WidgetRenderer.render(context, 42, type, settings(type, theme), facts(), width.toFloat(), height.toFloat()), width, height)
                val label = "$type-$theme-${if (night) "night" else "day"}-${width}x$height"
                fits(root, label)
                export(root, "$label.png")
            }
        }
    }
    @Test @Config(qualifiers = "xhdpi") fun pickerGoal() = renderPicker("goal")
    @Test @Config(qualifiers = "xhdpi") fun pickerPlanner() = renderPicker("planner")
    @Test @Config(qualifiers = "xhdpi") fun pickerQuickSave() = renderPicker("quickSave")
    @Test @Config(qualifiers = "xhdpi") fun pickerToday() = renderPicker("today")
    private fun renderPicker(type: String) {
        // Capture each picker in a fresh environment at native xhdpi density.
        val context = context()
        val theme = if (type == "planner") "mint" else "emerald"
        val root = measured(context, WidgetRenderer.render(context, 42, type, settings(type, theme), facts(), 300f, 220f), 300, 220)
        assertEquals(600, root.width)
        assertEquals(440, root.height)
        if (type == "quickSave") assertEquals("Motorcycle Fund", root.findViewById<TextView>(R.id.st_quick_goal).text.toString())
        else assertTrue(root.findViewById<TextView>(R.id.st_brand).text.startsWith("SAVETRACK"))
        fits(root, "picker-$type")
        export(root, "picker-$type.png")
    }
    @Test fun largeTextLongContentAndLargeCurrenciesFit() {
        for (type in WidgetStore.providers.keys) for (scale in listOf(1.5f, 2f)) {
            val context = context(scale = scale)
            val data = facts()
            data.getJSONObject("goal").put("title", "A very long shared savings goal for the whole family")
                .put("saved", "KWD 999,999,999,999,999.123").put("target", "KWD 999,999,999,999,999.999")
                .put("percent", 100).put("progress", 1000).put("remaining", "KWD 0.876").put("currency", "KWD").put("presets", JSONArray(listOf("KWD 50.000", "KWD 100.000", "KWD 500.000")))
            for ((width, height) in listOf(120 to 64, 300 to 220, 150 to 420, 350 to 420)) {
                val root = measured(context, WidgetRenderer.render(context, 42, type, settings(type).put("currency", "KWD"), data, width.toFloat(), height.toFloat()), width, height)
                fits(root, "$type ${width}x$height font=$scale")
                export(root, "$type-font$scale-${width}x$height.png")
            }
        }
    }
    @Test fun mediumLayoutsKeepTheNextTaskSavingsProgressAndPresetShortcuts() {
        val context = context()
        for ((type, required) in listOf("goal" to listOf("PHP ₱12,000.00", "40%"),
            "planner" to listOf("1 / 3", "Finish school project"), "quickSave" to listOf("PHP 0", "More", "Review"))) {
            val root = measured(context, WidgetRenderer.render(context, 42, type, settings(type), facts(), 300f, 220f), 300, 220)
            for (text in required) assertTrue("$type missing $text", visibleText(root).contains(text))
        }
    }
    @Test fun completedPercentagesRemainWholeAtTheMinimumSizeWithLargeText() {
        val context = context(scale = 2f)
        for (type in listOf("goal", "today")) for (percent in listOf(0, 40, 100)) {
            val data = facts()
            data.getJSONObject("goal").put("percent", percent).put("progress", percent * 10)
            val root = measured(context, WidgetRenderer.render(context, 42, type, settings(type), data, 110f, 56f), 110, 56)
            fits(root, "$type $percent minimum")
            val value = root.findViewById<TextView>(R.id.st_compact_value) ?: root.findViewById(R.id.st_today_goal_value)
            assertTrue(value.paint.measureText(value.text.toString()) <= value.width + 1)
            assertTrue(value.height >= value.lineHeight)
            assertTrue(value.text.contains("$percent%") || value.text.toString() == "Open")
        }
    }
    @Test fun systemAppearanceResolvesInTheHostWhileExplicitThemesStayFixed() {
        for (type in WidgetStore.providers.keys) for (theme in listOf("system", "mint", "emerald", "white")) {
            val remote = WidgetRenderer.render(context(), 42, type, settings(type, theme), facts(), 350f, 360f)
            val night = context(night = true)
            val root = measured(night, remote, 350, 360)
            val dark = theme == "system" || theme == "emerald"
            assertEquals("$type $theme", night.getColor(if (dark) R.color.st_night_secondary_text else R.color.st_day_secondary_text), root.findViewById<TextView>(if (type == "quickSave") R.id.st_quick_goal else R.id.st_brand).currentTextColor)
            assertEquals(night.resources.getDimension(android.R.dimen.system_app_widget_background_radius), (root.background as GradientDrawable).cornerRadius)
        }
    }
    @Test fun progressPrivacyAndEmptyStatesDoNotRevealPrivateFacts() {
        for (type in WidgetStore.providers.keys) {
            val data = facts()
            val root = measured(context(), WidgetRenderer.render(context(), 42, type, settings(type, privacy = "progress"), data, 350f, 360f), 350, 360)
            val labels = visibleText(root)
            assertFalse(labels.contains("Motorcycle")); assertFalse(labels.contains("12,000")); assertFalse(labels.contains("school project"))
            data.remove("goal")
            data.getJSONObject("planner").put("total", 0).put("remaining", 0).put("done", 0).put("tasks", JSONArray())
            fits(measured(context(), WidgetRenderer.render(context(), 42, type, settings(type), data, 300f, 220f), 300, 220), "$type empty")
        }
    }
    private fun visibleText(view: View): String = if (view.visibility != View.VISIBLE) "" else if (view is TextView) view.text.toString()
        else if (view is ViewGroup) (0 until view.childCount).joinToString { visibleText(view.getChildAt(it)) } else ""
    @Test fun semanticPalettesMeetTextAndProgressContrastTargets() {
        fun luminance(color: Int): Double {
            fun channel(value: Int) = (value / 255.0).let { if (it <= .04045) it / 12.92 else ((it + .055) / 1.055).pow(2.4) }
            return .2126 * channel(Color.red(color)) + .7152 * channel(Color.green(color)) + .0722 * channel(Color.blue(color))
        }
        fun contrast(first: Int, second: Int): Double {
            val a = luminance(first); val b = luminance(second)
            return (maxOf(a, b) + .05) / (minOf(a, b) + .05)
        }
        for (dark in listOf(false, true)) {
            val palette = WidgetVisualTokens.palette(app, dark)
            val background = app.getColor(if (dark) R.color.st_night_background else R.color.st_day_background)
            val surface = app.getColor(if (dark) R.color.st_night_surface else R.color.st_day_surface)
            val action = app.getColor(if (dark) R.color.st_night_action else R.color.st_day_action)
            val track = app.getColor(if (dark) R.color.st_night_track else R.color.st_day_track)
            for (color in listOf(palette.text, palette.secondaryText)) for (base in listOf(background, surface)) assertTrue("Text contrast dark=$dark", contrast(color, base) >= 4.5)
            assertTrue("Action contrast dark=$dark", contrast(palette.actionText, action) >= 4.5)
            assertTrue("Progress contrast dark=$dark", contrast(palette.accent, track) >= 3)
        }
    }
}
