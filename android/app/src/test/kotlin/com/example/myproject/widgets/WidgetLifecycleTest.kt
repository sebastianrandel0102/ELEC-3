package com.example.myproject.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ProgressBar
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
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 31, 35])
class WidgetLifecycleTest {
    private lateinit var context: Context
    private lateinit var store: WidgetStore
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("savetrack_widgets", Context.MODE_PRIVATE).edit().clear().commit()
        store = WidgetStore(context)
        store.setSession("alice")
    }
    private fun install(type: String): Int = shadowOf(AppWidgetManager.getInstance(context))
        .createWidget(WidgetStore.providers.getValue(type), R.layout.st_widget)
    private fun configure(id: Int, type: String, privacy: String = "full", theme: String = "emerald"): JSONObject = store.save(JSONObject().apply {
        put("schemaVersion", 1); put("id", id); put("type", type); put("uid", "alice")
        put("privacy", privacy); put("theme", theme); put("showTaskTitles", true)
        put("currency", "PHP"); put("presets", JSONArray(listOf("50.00", "100.00", "500.00")))
        if (type != "planner") put("goal", JSONObject().put("id", "testGoal").put("shared", false))
    }.toString())
    private fun snapshot(config: JSONObject): JSONObject = JSONObject().apply {
        put("schemaVersion", 1); put("id", config.getInt("id")); put("type", config.getString("type"))
        put("uid", "alice"); put("revision", config.getLong("revision")); put("privacy", config.getString("privacy"))
        put("updatedAt", System.currentTimeMillis()); put("confirmedAt", System.currentTimeMillis())
        put("day", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
        put("timezoneOffsetMinutes", TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000)
        put("state", "ready")
        put("goal", JSONObject().put("title", "Private motorcycle fund").put("saved", "PHP ₱12,000.00")
            .put("target", "PHP ₱30,000.00").put("remaining", "PHP ₱18,000.00")
            .put("currency", "PHP").put("percent", 40).put("progress", 400).put("status", "Active")
            .put("canSave", true).put("deadline", "2027-01-31").put("presets", JSONArray(listOf("PHP ₱50.00", "PHP ₱100.00", "PHP ₱500.00"))))
        put("planner", JSONObject().put("state", "ready").put("done", 1).put("total", 5).put("remaining", 4).put("progress", 200)
            .put("tasks", JSONArray((1..5).map { JSONObject().put("id", "task$it").put("title", "Private task $it").put("priority", "High").put("time", "09:00") })))
    }
    @Test fun accountsAndReconfigurationCannotReviveOldSnapshots() {
        val id = install("goal")
        val config = configure(id, "goal")
        val payload = snapshot(config).toString()
        store.publish("alice", listOf(payload))
        assertNotNull(store.snapshot(id))
        configure(id, "goal", "hidden")
        store.publish("alice", listOf(payload))
        assertNull(store.snapshot(id))
        store.setSession(null)
        assertNull(store.config(id)); assertNull(store.snapshot(id))
        store.setSession("bob")
        assertNull(store.config(id))
        assertThrows(IllegalArgumentException::class.java) { store.publish("alice", listOf(payload)) }
    }
    @Test fun instanceRemovalAndRestorationAreIsolated() {
        val first = install("goal"); val second = install("goal")
        configure(first, "goal"); configure(second, "goal", "progress", "mint")
        store.remove(intArrayOf(first))
        assertNull(store.config(first)); assertNotNull(store.config(second))
        store.restored(intArrayOf(first), intArrayOf(999))
        assertNull(store.config(999)); assertNotNull(store.config(second))
    }
    @Test fun nativeStorageSanitizesPrivacyBeforeRendering() {
        for (privacy in listOf("progress", "hidden")) {
            val id = install("today"); val config = configure(id, "today", privacy)
            store.publish("alice", listOf(snapshot(config).toString()))
            val raw = store.snapshot(id)!!.toString()
            assertFalse(raw.contains("Private motorcycle")); assertFalse(raw.contains("Private task"))
            assertFalse(raw.contains("12,000"))
            if (privacy == "hidden") assertFalse(raw.contains("progress"))
        }
    }
    @Test fun explicitThemesApplyToEveryWidgetIncludingPlanner() {
        for (type in WidgetStore.providers.keys) {
            val id = install(type)
            for (theme in listOf("emerald", "mint", "white")) {
                val config = configure(id, type, theme = theme)
                val root = WidgetRenderer.render(context, id, type, config, snapshot(config), 350f, 300f).apply(context, FrameLayout(context))
                val expected = context.getColor(if (theme == "emerald") R.color.st_night_secondary_text else R.color.st_day_secondary_text)
                assertEquals("$type $theme", expected, root.findViewById<TextView>(R.id.st_brand).currentTextColor)
            }
        }
    }
    @Test fun allTypesInflateAndFitAtFiveSizesAndThreeFontScales() {
        for (type in WidgetStore.providers.keys) {
            val id = install(type); val config = configure(id, type)
            val payload = snapshot(config)
            for (fontScale in listOf(1f, 1.5f, 2f)) {
                val scaled = context.createConfigurationContext(Configuration(context.resources.configuration).apply { this.fontScale = fontScale })
                for ((width, height) in listOf(120 to 64, 150 to 150, 300 to 220, 300 to 300, 350 to 420, 150 to 420, 350 to 100)) {
                    val remote = WidgetRenderer.render(scaled, id, type, config, payload, width.toFloat(), height.toFloat())
                    val root = remote.apply(scaled, FrameLayout(scaled))
                    val density = scaled.resources.displayMetrics.density
                    root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
                    root.layout(0, 0, root.measuredWidth, root.measuredHeight)
                    assertFits(root, "$type ${width}x$height font=$fontScale")
                }
            }
        }
    }
    @Test fun resizedTodayKeepsBothSummariesAndUsesTheAvailableArea() {
        val id = install("today"); val config = configure(id, "today", theme = "mint")
        val payload = snapshot(config)
        payload.getJSONObject("goal").put("title", "group").put("percent", 20).put("progress", 200)
        payload.getJSONObject("planner").put("remaining", 1).put("total", 2).put("done", 1)
        val root = measuredToday(context, id, config, payload, 270, 190)
        assertEquals("20%", root.findViewById<TextView>(R.id.st_today_goal_value).text.toString())
        assertEquals("1 / 2", root.findViewById<TextView>(R.id.st_today_tasks_value).text.toString())
        assertEquals("1 task left", root.findViewById<TextView>(R.id.st_today_tasks_title).text.toString())
        val savings = root.findViewById<View>(R.id.st_today_goal)
        val tasks = root.findViewById<View>(R.id.st_today_tasks)
        assertEquals(savings.top, tasks.top)
        assertTrue(tasks.left >= savings.right)
        assertTrue("Cards should fill the body, not float in its center", savings.height >= root.height / 2)
        // Progress visibility uses actual font metrics in TodayWidgetRenderingTest;
        // legacy graphics may trim it because its synthetic text rows are taller.
        assertEquals(200, root.findViewById<ProgressBar>(R.id.st_today_goal_progress).progress)
        assertFits(root, "Today screenshot size")
        for ((panel, destination) in listOf(savings to "goal", tasks to "planner")) {
            assertTrue(panel.performClick())
            assertEquals(destination, shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity.getStringExtra("widgetAction"))
        }
    }
    @Test fun tallTodayStacksBothSummariesEvenWithLargeText() {
        val id = install("today"); val config = configure(id, "today")
        for (fontScale in listOf(1f, 1.5f, 2f)) {
            val scaled = context.createConfigurationContext(Configuration(context.resources.configuration).apply { this.fontScale = fontScale })
            val root = measuredToday(scaled, id, config, snapshot(config), 150, 420)
            val savings = root.findViewById<View>(R.id.st_today_goal)
            val tasks = root.findViewById<View>(R.id.st_today_tasks)
            assertTrue("Tall layout must stack at font=$fontScale", tasks.top >= savings.bottom)
            assertEquals(savings.left, tasks.left)
            assertTrue(root.findViewById<TextView>(R.id.st_today_goal_value).text.isNotBlank())
            assertTrue(root.findViewById<TextView>(R.id.st_today_tasks_value).text.isNotBlank())
            assertFits(root, "Tall Today font=$fontScale")
        }
    }
    @Test fun todayReapplicationClearsPrivateOrStaleDetails() {
        val id = install("today"); val config = configure(id, "today")
        val payload = snapshot(config)
        val root = measuredToday(context, id, config, payload, 420, 420)
        assertTrue(texts(root).contains("Private task 1"))
        WidgetRenderer.render(context, id, "today", config, payload, 270f, 160f).reapply(context, root)
        WidgetRenderer.render(context, id, "today", config, payload, 420f, 420f).reapply(context, root)
        assertTrue(texts(root).contains("Private task 1"))
        val privateConfig = configure(id, "today", privacy = "progress")
        WidgetRenderer.render(context, id, "today", privateConfig, payload.put("day", "2000-01-01"), 420f, 420f).reapply(context, root)
        assertFalse(texts(root).contains("Private"))
        assertFalse(texts(root).contains("12,000"))
        assertEquals("—", root.findViewById<TextView>(R.id.st_today_tasks_value).text.toString())
        assertEquals(View.GONE, root.findViewById<View>(R.id.st_today_tasks_progress).visibility)
    }
    private fun measuredToday(context: Context, id: Int, config: JSONObject, payload: JSONObject, width: Int, height: Int): View {
        val root = WidgetRenderer.render(context, id, "today", config, payload, width.toFloat(), height.toFloat()).apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
        root.layout(0, 0, root.measuredWidth, root.measuredHeight)
        return root
    }
    private fun assertFits(view: View, message: String) {
        if (view.visibility != View.VISIBLE) return
        if (view is ViewGroup) for (i in 0 until view.childCount) {
            val child = view.getChildAt(i)
            if (child.visibility != View.VISIBLE) continue
            assertTrue("$message child ${child.id} top=${child.top}", child.top >= 0)
            assertTrue("$message child ${child.id} bottom=${child.bottom} parent=${view.height}", child.bottom <= view.height + 1)
            assertFits(child, message)
        }
    }
    @Test fun midnightAndExpiredSnapshotsDoNotShowOldPrivateContent() {
        val id = install("planner"); val config = configure(id, "planner")
        val payload = snapshot(config).put("day", "2000-01-01")
        val root = WidgetRenderer.render(context, id, "planner", config, payload, 350f, 420f).apply(context, FrameLayout(context))
        assertFalse(texts(root).contains("Private task")); assertTrue(texts(root).contains("refresh"))
        payload.put("updatedAt", 1)
        val expired = WidgetRenderer.render(context, id, "planner", config, payload, 350f, 420f).apply(context, FrameLayout(context))
        assertFalse(texts(expired).contains("Private task"))
    }
    @Test fun cachedRepaintsNeverRenewFreshnessAndCorruptSnapshotsAreRejected() {
        val id = install("goal"); val config = configure(id, "goal")
        store.publish("alice", listOf(snapshot(config).put("updatedAt", 1).put("confirmedAt", 1).toString()))
        store.publish("alice", listOf(snapshot(config).put("cached", true).toString()))
        assertEquals(1L, store.snapshot(id)!!.getLong("freshnessAt"))
        context.getSharedPreferences("savetrack_widgets", Context.MODE_PRIVATE).edit().putString("snapshot_$id", "{broken").commit()
        assertNull(store.snapshot(id))
        WidgetRenderer.update(context, id)
    }
    @Test fun reapplyingNeutralStateClearsPriorPhotoActionsAndPrivateText() {
        val id = install("goal"); val config = configure(id, "goal")
        val root = WidgetRenderer.render(context, id, "goal", config, snapshot(config), 350f, 420f).apply(context, FrameLayout(context))
        val image = root.findViewById<ImageView>(R.id.st_cover)
        image.setImageBitmap(Bitmap.createBitmap(16, 16, Bitmap.Config.ARGB_8888))
        image.visibility = View.VISIBLE
        store.setSession(null)
        WidgetRenderer.render(context, id, "goal", null, null, 350f, 420f).reapply(context, root)
        assertEquals(View.GONE, image.visibility)
        assertNull(image.drawable)
        assertEquals(View.GONE, root.findViewById<View>(R.id.st_actions).visibility)
        assertFalse(texts(root).contains("Private motorcycle"))
    }
    @Test fun presetActionsAreDistinctPerInstanceAndOnlyLaunchTheApp() {
        val ids = listOf(install("quickSave"), install("quickSave"))
        val intents = ids.map { id ->
            val config = configure(id, "quickSave")
            val before = store.config(id).toString()
            val root = WidgetRenderer.render(context, id, "quickSave", config, snapshot(config), 350f, 300f).apply(context, FrameLayout(context))
            val button = findText(root, "+₱50.00")
            assertNotNull(button)
            assertTrue(button!!.performClick())
            val launched = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
            assertEquals("savetrack.widget", launched.action)
            assertEquals(id, launched.getIntExtra("widgetId", -1))
            assertEquals("save", launched.getStringExtra("widgetAction"))
            assertEquals(0, launched.getIntExtra("preset", -1))
            assertEquals(before, store.config(id).toString())
            launched
        }
        assertNotEquals(intents[0].data, intents[1].data)
    }
    private fun findText(view: View, label: String): TextView? {
        if (view is TextView && view.text.toString() == label) return view
        if (view is ViewGroup) for (index in 0 until view.childCount) {
            findText(view.getChildAt(index), label)?.let { return it }
        }
        return null
    }
    private fun texts(view: View): String = if (view is TextView) view.text.toString() else if (view is ViewGroup) (0 until view.childCount).joinToString { texts(view.getChildAt(it)) } else ""
}
