package com.crossplatformtodo

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
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

            val isDark = WidgetConfigureActivity.isDarkTheme(context, widgetId)
            val opacity = WidgetConfigureActivity.getOpacity(context, widgetId)
            val alpha = (opacity / 100f * 255).toInt().coerceIn(0, 255)

            if (isDark) {
                views.setInt(R.id.widget_inner_panel, "setBackgroundColor",
                    Color.argb(alpha, 0, 0, 0))
                views.setInt(R.id.widget_tasks_container, "setBackgroundColor",
                    Color.argb(alpha, 26, 26, 26))

                views.setTextColor(R.id.widget_title, Color.parseColor("#F9FAFB"))
                views.setTextColor(R.id.widget_updated_at, Color.parseColor("#9CA3AF"))
                views.setTextColor(R.id.widget_empty_text, Color.parseColor("#D1D5DB"))
            } else {
                views.setInt(R.id.widget_inner_panel, "setBackgroundColor",
                    Color.argb(alpha, 255, 255, 255))
                views.setInt(R.id.widget_tasks_container, "setBackgroundColor",
                    Color.argb(alpha, 243, 244, 246))

                views.setTextColor(R.id.widget_title, Color.parseColor("#111827"))
                views.setTextColor(R.id.widget_updated_at, Color.parseColor("#6B7280"))
                views.setTextColor(R.id.widget_empty_text, Color.parseColor("#374151"))
            }

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(
                R.id.widget_updated_at,
                if (updatedAt.isNullOrBlank()) "" else "Updated $updatedAt"
            )

            val taskCount = widgetData.getString("today_task_count", "0")?.toIntOrNull() ?: 0
            views.setViewVisibility(
                R.id.widget_empty_text,
                if (taskCount == 0) View.VISIBLE else View.GONE
            )
            val listIntent = Intent(context, TodoTodayWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(EXTRA_IS_DARK, isDark)
            }
            views.setRemoteAdapter(R.id.widget_tasks_list, listIntent)
            views.setEmptyView(R.id.widget_tasks_list, R.id.widget_empty_text)

            val toggleTemplateIntent = Intent(context, WidgetToggleReceiver::class.java).apply {
                action = WidgetToggleReceiver.ACTION_WIDGET_TOGGLE
            }
            var templateFlags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                templateFlags = templateFlags or PendingIntent.FLAG_MUTABLE
            }
            val toggleTemplatePendingIntent = PendingIntent.getBroadcast(
                context,
                widgetId,
                toggleTemplateIntent,
                templateFlags
            )
            views.setPendingIntentTemplate(R.id.widget_tasks_list, toggleTemplatePendingIntent)

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

            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_tasks_list)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        appWidgetIds.forEach { WidgetConfigureActivity.deletePrefs(context, it) }
    }

    companion object {
        const val EXTRA_IS_DARK = "extra_is_dark"
    }
}
