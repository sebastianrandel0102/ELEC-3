package com.example.myproject.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle

abstract class SaveTrackWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { WidgetRenderer.update(context, it) }
        if (QuickSaveStore(context).pending() != null) QuickSaveJobService.schedule(context)
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        WidgetRenderer.update(context, id, options)
    }
    override fun onDeleted(context: Context, ids: IntArray) { WidgetStore(context).remove(ids) }
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        WidgetStore(context).restored(oldIds, newIds)
    }
}
class SaveTrackGoalWidget : SaveTrackWidgetProvider()
class SaveTrackPlannerWidget : SaveTrackWidgetProvider()
class SaveTrackQuickSaveWidget : SaveTrackWidgetProvider()
class SaveTrackTodayWidget : SaveTrackWidgetProvider()

class WidgetCalendarReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Local repaint only; yesterday's task payload is never relabelled today.
        WidgetRenderer.updateAll(context)
        if (QuickSaveStore(context).pending() != null) QuickSaveJobService.schedule(context)
    }
}
