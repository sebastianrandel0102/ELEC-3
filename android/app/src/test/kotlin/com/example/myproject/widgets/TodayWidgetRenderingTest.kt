package com.example.myproject.widgets

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.example.myproject.R
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
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

/** Real text metrics and pixels complement the legacy multi-API bounds matrix. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [31])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TodayWidgetRenderingTest {
    @Test fun summariesRemainReadableAcrossLauncherShapes() {
        val app: Context = RuntimeEnvironment.getApplication()
        WidgetStore(app).setSession("alice")
        val config = JSONObject().put("theme", "mint").put("privacy", "full").put("showTaskTitles", true)
        val payload = JSONObject().put("state", "ready").put("updatedAt", System.currentTimeMillis())
            .put("confirmedAt", System.currentTimeMillis())
            .put("day", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()))
            .put("timezoneOffsetMinutes", TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000)
            .put("goal", JSONObject().put("title", "group").put("percent", 20).put("progress", 200)
                .put("saved", "PHP ₱200.00").put("canSave", true))
            .put("planner", JSONObject().put("state", "ready").put("total", 2).put("done", 1).put("remaining", 1).put("progress", 500)
                .put("tasks", JSONArray().put(JSONObject().put("id", "task").put("title", "Review today's plan"))))
        for ((width, height, scale) in listOf(Triple(270, 190, 1f), Triple(350, 100, 1f), Triple(150, 420, 1f),
            Triple(300, 220, 1.5f), Triple(150, 420, 2f), Triple(120, 64, 2f), Triple(350, 420, 1f))) {
            val context = app.createConfigurationContext(Configuration(app.resources.configuration).apply { fontScale = scale })
            config.put("theme", if (width == 350 && height == 420) "emerald" else "mint")
            val remote = WidgetRenderer.render(context, 42, "today", config, payload, width.toFloat(), height.toFloat())
            val root = remote.apply(context, FrameLayout(context))
            val density = context.resources.displayMetrics.density
            root.measure(View.MeasureSpec.makeMeasureSpec((width * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((height * density).toInt(), View.MeasureSpec.EXACTLY))
            root.layout(0, 0, root.measuredWidth, root.measuredHeight)
            if (width == 270 && height == 190 || width == 300 && height == 220) {
                assertEquals(View.VISIBLE, root.findViewById<View>(R.id.st_today_goal_progress).visibility)
                assertEquals(View.VISIBLE, root.findViewById<View>(R.id.st_today_tasks_progress).visibility)
            }
            for (id in listOf(R.id.st_today_goal_value, R.id.st_today_tasks_value)) {
                val value = root.findViewById<TextView>(id)
                assertTrue("Metric clipped at ${width}x$height font=$scale", value.paint.measureText(value.text.toString()) <= value.width + 1)
                assertTrue("Metric height clipped at ${width}x$height font=$scale", value.height >= value.lineHeight)
            }
            // Optional artifact output supports visual review without a phone.
            System.getenv("SAVETRACK_WIDGET_PREVIEW_DIR")?.let { directory ->
                val file = File(directory, "today-${width}x$height-font$scale.png")
                file.parentFile?.mkdirs()
                val bitmap = Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
                root.draw(Canvas(bitmap))
                file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
        }
    }
}
