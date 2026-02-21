package com.example.simpletodo

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Paint
import android.os.Build
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TodoTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.todo_today_widget)

            val title = widgetData.getString("today_title", "Today")
            val updatedAt = widgetData.getString("today_updated_at", "")

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(
                R.id.widget_updated_at,
                if (updatedAt.isNullOrBlank()) "" else "Updated $updatedAt"
            )

            val rowIds = intArrayOf(
                R.id.widget_row_0,
                R.id.widget_row_1,
                R.id.widget_row_2,
                R.id.widget_row_3
            )
            val titleIds = intArrayOf(
                R.id.widget_task_0,
                R.id.widget_task_1,
                R.id.widget_task_2,
                R.id.widget_task_3
            )
            val checkIds = intArrayOf(
                R.id.widget_check_0,
                R.id.widget_check_1,
                R.id.widget_check_2,
                R.id.widget_check_3
            )

            var visibleCount = 0
            for (i in 0..3) {
                val taskId = widgetData.getString("today_task_${i}_id", "")
                val taskTitle = widgetData.getString("today_task_${i}_title", "")
                val toggleDone = widgetData.getString("today_task_${i}_toggle_done", "0") == "1"
                val isDone = widgetData.getString("today_task_${i}_is_done", "0") == "1"

                if (taskId.isNullOrBlank() || taskTitle.isNullOrBlank()) {
                    views.setViewVisibility(rowIds[i], View.GONE)
                    views.setViewVisibility(checkIds[i], View.GONE)
                    continue
                }

                visibleCount += 1
                views.setViewVisibility(rowIds[i], View.VISIBLE)
                views.setTextViewText(titleIds[i], taskTitle)
                views.setInt(
                    titleIds[i],
                    "setPaintFlags",
                    if (isDone) Paint.STRIKE_THRU_TEXT_FLAG else 0
                )
                views.setViewVisibility(
                    checkIds[i],
                    if (isDone) View.VISIBLE else View.GONE
                )

                val toggleIntent = buildTogglePendingIntent(
                    context,
                    taskId,
                    toggleDone
                )
                views.setOnClickPendingIntent(rowIds[i], toggleIntent)
            }
            views.setViewVisibility(
                R.id.widget_empty_text,
                if (visibleCount == 0) View.VISIBLE else View.GONE
            )

            val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("simpletodo://refresh")
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshIntent)

            val addIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("simpletodo://add")
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun buildTogglePendingIntent(
        context: Context,
        taskId: String,
        toggleDone: Boolean
    ): PendingIntent {
        val uri = Uri.parse("simpletodo://toggle?taskId=$taskId&done=${if (toggleDone) "1" else "0"}")
        val intent = Intent(context, WidgetToggleReceiver::class.java).apply {
            action = WidgetToggleReceiver.ACTION_WIDGET_TOGGLE
            data = uri
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, taskId.hashCode(), intent, flags)
    }
}
