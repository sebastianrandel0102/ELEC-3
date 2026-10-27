package com.example.myproject.widgets

import android.app.job.JobScheduler
import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.FrameLayout
import android.widget.TextView
import android.view.View
import android.view.ViewGroup
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 31, 35])
class QuickSaveTest {
    private lateinit var app: Context
    private lateinit var widgets: WidgetStore
    private lateinit var input: QuickSaveStore
    @Before fun setup() {
        app = RuntimeEnvironment.getApplication()
        app.getSharedPreferences("savetrack_widgets", Context.MODE_PRIVATE).edit().clear().commit()
        widgets = WidgetStore(app); widgets.setSession("alice"); input = QuickSaveStore(app)
    }
    private fun install(): JSONObject {
        val id = shadowOf(AppWidgetManager.getInstance(app)).createWidget(SaveTrackQuickSaveWidget::class.java, R.layout.st_widget)
        val config = widgets.save(JSONObject().put("schemaVersion", 1).put("id", id).put("type", "quickSave")
            .put("uid", "alice").put("theme", "mint").put("privacy", "full").put("currency", "PHP")
            .put("goal", JSONObject().put("id", "goal-1234567890123456").put("shared", false))
            .put("presets", JSONArray(listOf("50.00"))).toString())
        widgets.publish("alice", listOf(JSONObject().put("schemaVersion", 1).put("id", id).put("type", "quickSave")
            .put("uid", "alice").put("revision", config.getLong("revision")).put("privacy", "full")
            .put("state", "ready").put("updatedAt", System.currentTimeMillis())
            .put("goal", JSONObject().put("title", "My goal").put("saved", "PHP 0.00").put("target", "PHP 100.00")
                .put("remaining", "PHP 100.00").put("percent", 0).put("progress", 0).put("currency", "PHP")
                .put("currencyDigits", 2).put("canSave", true)).toString()))
        return config
    }
    private fun tap(config: JSONObject, control: String): Boolean = input.dispatch(config.getInt("id"), config.getLong("revision"), input.state(config.getInt("id")).getString("flow"), control)
    @Test fun exactInputRulesCoverDigitsDecimalsBackspaceAndClear() {
        var value = ""
        for (key in listOf("0", ".", "1", "2", "3", ".")) value = QuickSaveInput.edit(value, "digit:$key", 2)
        assertEquals("0.12", value)
        assertEquals("0.1", QuickSaveInput.edit(value, "back", 2))
        assertEquals("", QuickSaveInput.edit(value, "clear", 2))
        assertEquals("1", QuickSaveInput.edit("1", "digit:.", 0))
        assertNull(QuickSaveInput.review("0", 2)); assertNull(QuickSaveInput.review("1.1", 0))
        assertEquals("1", QuickSaveInput.review("1.", 2))
        assertEquals("1.234", QuickSaveInput.review("1.234", 3))
        assertNull(QuickSaveInput.review("1000000000001", 2))
        assertNull(QuickSaveInput.review("1000000000.01", 2, true))
        assertEquals("1000000000", QuickSaveInput.review("1000000000", 2, true))
    }
    @Test fun rapidInputAndResizeKeepInstancesIndependent() {
        val a = install(); val b = install()
        repeat(4) { tap(a, "digit:1"); tap(b, "digit:2") }
        tap(a, "digit:."); tap(a, "digit:5")
        val id = a.getInt("id")
        val before = input.state(id).toString()
        for ((w, h) in listOf(180f to 210f, 300f to 220f, 350f to 420f)) {
            val root = WidgetRenderer.render(app, id, "quickSave", a, widgets.snapshot(id), w, h).apply(app, FrameLayout(app))
            assertTrue(root.findViewById<TextView>(R.id.st_quick_amount).text.contains("1111.5"))
        }
        assertEquals(before, QuickSaveStore(app).state(id).toString())
        assertEquals("2222", input.state(b.getInt("id")).getString("amount"))
        tap(a, "clear"); tap(a, "preset:0"); assertEquals("50.00", input.state(id).getString("amount"))
    }
    @Test fun reviewCancelConfirmAndRetryRetainExactlyOneImmutableOperation() {
        val config = install(); val id = config.getInt("id")
        tap(config, "digit:5"); tap(config, "review"); tap(config, "cancel")
        assertNull(input.operation(id)); assertEquals("5", input.state(id).getString("amount"))
        tap(config, "review")
        val confirmFlow = input.state(id).getString("flow")
        assertTrue(tap(config, "confirm"))
        val operation = input.operation(id)!!.toString()
        assertFalse(input.dispatch(id, config.getLong("revision"), confirmFlow, "confirm"))
        assertFalse(tap(config, "digit:9")); assertFalse(tap(config, "cancel"))
        assertThrows(IllegalStateException::class.java) { widgets.save(config.toString()) }
        val request = input.operation(id)!!.getString("requestId")
        input.complete(id, "wrong-receipt", true); assertEquals("pending", input.state(id).getString("stage"))
        input.complete(id, request, false); assertEquals("retry", input.state(id).getString("stage"))
        tap(config, "retry"); assertEquals(operation, input.operation(id)!!.toString())
        input.complete(id, request, true); assertEquals("saved", input.state(id).getString("stage"))
        assertNull(input.operation(id)); assertNull(input.pending())
        assertFalse(input.dispatch(id, config.getLong("revision"), confirmFlow, "confirm"))
        tap(config, "new"); assertEquals("", input.state(id).getString("amount"))
    }
    @Test fun accountChangesDeletionAndStaleIntentsCannotRevivePrivateInput() {
        val a = install(); val b = install(); val id = a.getInt("id")
        tap(a, "digit:9"); tap(a, "review"); tap(a, "confirm")
        widgets.remove(intArrayOf(b.getInt("id")))
        assertNotNull(input.operation(id))
        widgets.setSession("bob")
        assertEquals("", input.state(id).getString("amount")); assertNull(input.operation(id))
        assertFalse(tap(a, "confirm")); assertNull(input.pending())
    }
    @Test fun identitiesSeparateControlsInstancesAndReviewGenerations() {
        val a = install(); val b = install()
        fun action(c: JSONObject, flow: String, key: String) = QuickSaveActionReceiver.action(app, c.getInt("id"), c.getLong("revision"), flow, key)
        assertNotEquals(action(a, "initial", "digit:1"), action(a, "initial", "digit:2"))
        assertNotEquals(action(a, "initial", "digit:1"), action(b, "initial", "digit:1"))
        assertNotEquals(action(a, "review1", "confirm"), action(a, "review2", "confirm"))
        assertEquals(QuickSaveActionReceiver::class.java.name, shadowOf(action(a, "initial", "digit:1")).savedIntent.component!!.className)
    }
    @Test fun networkWorkIsPersistedAndDoesNotReplaceAnExistingJob() {
        QuickSaveJobService.schedule(app)
        val scheduler = app.getSystemService(JobScheduler::class.java)
        val job = scheduler.allPendingJobs.single()
        assertTrue(job.isPersisted); assertEquals(android.app.job.JobInfo.NETWORK_TYPE_ANY, job.networkType)
        QuickSaveJobService.schedule(app)
        assertEquals(1, scheduler.allPendingJobs.size)
    }
    @Test @Config(sdk = [31]) fun everySaveStageFitsAtThePracticalMinimum() {
        val config = install(); val id = config.getInt("id")
        fun fits(view: View) {
            if (view.visibility != View.VISIBLE || view !is ViewGroup) return
            for (index in 0 until view.childCount) {
                val child = view.getChildAt(index)
                if (child.visibility != View.VISIBLE) continue
                assertTrue("${input.state(id).optString("stage")} view=${child.id} top=${child.top}", child.top >= 0)
                assertTrue("${input.state(id).optString("stage")} view=${child.id} bottom=${child.bottom} / ${view.height}", child.bottom <= view.height + 1)
                fits(child)
            }
        }
        fun verify() {
            val root = QuickSaveRenderer.render(app, id, config, widgets.snapshot(id)?.optJSONObject("goal"), 180f, 210f).apply(app, FrameLayout(app))
            val density = app.resources.displayMetrics.density
            root.measure(View.MeasureSpec.makeMeasureSpec((180 * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((210 * density).toInt(), View.MeasureSpec.EXACTLY))
            root.layout(0, 0, root.measuredWidth, root.measuredHeight)
            fits(root)
        }
        tap(config, "digit:5"); verify()
        tap(config, "review"); verify()
        tap(config, "confirm"); verify()
        val request = input.operation(id)!!.getString("requestId")
        input.complete(id, request, false); verify()
        tap(config, "retry"); verify()
        input.complete(id, request, true); verify()
        tap(config, "new"); verify()
    }
}
