package com.crossplatformtodo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

class TodoTodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return TodoTodayRemoteViewsFactory(applicationContext, packageName, widgetId)
    }
}

private class TodoTodayRemoteViewsFactory(
    private val context: Context,
    private val packageName: String,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private val taskIds = mutableListOf<String>()
    private val taskTitles = mutableListOf<String>()
    private val taskToggleDone = mutableListOf<String>()
    private val taskIsDone = mutableListOf<String>()
    private var isDark = true

    override fun onCreate() {
        loadFromPrefs()
    }

    override fun onDataSetChanged() {
        loadFromPrefs()
    }

    override fun onDestroy() {
        taskIds.clear()
        taskTitles.clear()
        taskToggleDone.clear()
        taskIsDone.clear()
    }

    override fun getCount(): Int {
        return taskIds.size
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= taskIds.size) {
            return null
        }

        val remoteViews = RemoteViews(packageName, R.layout.todo_today_widget_list_item)
        val title = taskTitles[position]
        val done = taskIsDone[position] == "1"
        val toggleDone = taskToggleDone[position]

        remoteViews.setTextViewText(R.id.widget_item_title, title)
        remoteViews.setInt(
            R.id.widget_item_title,
            "setPaintFlags",
            if (done) Paint.STRIKE_THRU_TEXT_FLAG else 0
        )
        remoteViews.setViewVisibility(
            R.id.widget_item_check,
            if (done) View.VISIBLE else View.GONE
        )

        if (isDark) {
            remoteViews.setInt(R.id.widget_task_row_root, "setBackgroundColor",
                Color.parseColor("#262626"))
            remoteViews.setTextColor(R.id.widget_item_title,
                if (done) Color.parseColor("#6B7280") else Color.parseColor("#E5E7EB"))
            remoteViews.setTextColor(R.id.widget_item_check, Color.parseColor("#22C55E"))
        } else {
            remoteViews.setInt(R.id.widget_task_row_root, "setBackgroundColor",
                Color.parseColor("#FFFFFF"))
            remoteViews.setTextColor(R.id.widget_item_title,
                if (done) Color.parseColor("#9CA3AF") else Color.parseColor("#111827"))
            remoteViews.setTextColor(R.id.widget_item_check, Color.parseColor("#16A34A"))
        }

        val fillInIntent = Intent().apply {
            data = Uri.parse("simpletodo://toggle?taskId=${taskIds[position]}&done=$toggleDone")
        }
        remoteViews.setOnClickFillInIntent(R.id.widget_task_row_root, fillInIntent)
        return remoteViews
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return taskIds[position].hashCode().toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    private fun loadFromPrefs() {
        taskIds.clear()
        taskTitles.clear()
        taskToggleDone.clear()
        taskIsDone.clear()

        isDark = WidgetConfigureActivity.isDarkTheme(context, widgetId)

        val prefs = HomeWidgetPlugin.getData(context)
        val taskCount = prefs.getString("today_task_count", "0")?.toIntOrNull() ?: 0

        for (i in 0 until taskCount) {
            val id = prefs.getString("today_task_${i}_id", "") ?: ""
            val title = prefs.getString("today_task_${i}_title", "") ?: ""
            val toggle = prefs.getString("today_task_${i}_toggle_done", "0") ?: "0"
            val done = prefs.getString("today_task_${i}_is_done", "0") ?: "0"

            if (id.isBlank() || title.isBlank()) continue

            taskIds.add(id)
            taskTitles.add(title)
            taskToggleDone.add(toggle)
            taskIsDone.add(done)
        }
    }
}
