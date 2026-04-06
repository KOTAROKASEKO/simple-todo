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
    private val rows = mutableListOf<WidgetRow>()
    private var isDark = true

    override fun onCreate() {
        loadFromPrefs()
    }

    override fun onDataSetChanged() {
        loadFromPrefs()
    }

    override fun onDestroy() {
        rows.clear()
    }

    override fun getCount(): Int {
        return rows.size
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= rows.size) {
            return null
        }

        val row = rows[position]
        val remoteViews = RemoteViews(packageName, R.layout.todo_today_widget_list_item)
        val title = row.title
        val done = row.done
        val toggleDone = row.toggleDone

        remoteViews.setTextViewText(R.id.widget_item_title, title)
        remoteViews.setInt(
            R.id.widget_item_title,
            "setPaintFlags",
            if (done && !row.isChecklistChild) Paint.STRIKE_THRU_TEXT_FLAG else 0
        )
        remoteViews.setViewVisibility(
            R.id.widget_item_check,
            if (done) View.VISIBLE else View.GONE
        )

        if (row.isChecklistChild) {
            remoteViews.setInt(R.id.widget_task_row_root, "setBackgroundColor", Color.TRANSPARENT)
            remoteViews.setTextColor(
                R.id.widget_item_title,
                if (isDark) Color.parseColor("#D1D5DB") else Color.parseColor("#374151")
            )
            remoteViews.setTextColor(
                R.id.widget_item_check,
                if (isDark) Color.parseColor("#86EFAC") else Color.parseColor("#16A34A")
            )
        } else {
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
        }

        val fillInIntent = Intent()
        if (row.isChecklistChild) {
            fillInIntent.data = Uri.Builder()
                .scheme("simpletodo")
                .authority("toggleChecklist")
                .appendQueryParameter("taskId", row.taskId)
                .appendQueryParameter("index", (row.checklistIndex ?: -1).toString())
                .appendQueryParameter("done", toggleDone)
                .appendQueryParameter("widgetId", widgetId.toString())
                .build()
        } else if (row.hasChecklist) {
            fillInIntent.data = Uri.Builder()
                .scheme("simpletodo")
                .authority("expand")
                .appendQueryParameter("taskId", row.taskId)
                .appendQueryParameter("widgetId", widgetId.toString())
                .build()
        } else {
            fillInIntent.data = Uri.Builder()
                .scheme("simpletodo")
                .authority("toggle")
                .appendQueryParameter("taskId", row.taskId)
                .appendQueryParameter("done", toggleDone)
                .build()
        }
        remoteViews.setOnClickFillInIntent(R.id.widget_task_row_root, fillInIntent)
        return remoteViews
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 2
    }

    override fun getItemId(position: Int): Long {
        return rows[position].stableId
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    private fun loadFromPrefs() {
        rows.clear()

        isDark = WidgetConfigureActivity.isDarkTheme(context, widgetId)

        val prefs = HomeWidgetPlugin.getData(context)
        val taskCount = prefs.getString("today_task_count", "0")?.toIntOrNull() ?: 0
        val expandedTaskId = prefs.getString("today_widget_${widgetId}_expanded_task_id", "") ?: ""

        for (i in 0 until taskCount) {
            val id = prefs.getString("today_task_${i}_id", "") ?: ""
            val title = prefs.getString("today_task_${i}_title", "") ?: ""
            val toggle = prefs.getString("today_task_${i}_toggle_done", "0") ?: "0"
            val done = prefs.getString("today_task_${i}_is_done", "0") ?: "0"
            val checklistCount = prefs.getString("today_task_${i}_checklist_count", "0")?.toIntOrNull() ?: 0

            if (id.isBlank() || title.isBlank()) continue

            val isExpanded = checklistCount > 0 && expandedTaskId == id
            val displayTitle = if (checklistCount > 0) {
                if (isExpanded) "▾ $title" else "▸ $title"
            } else {
                title
            }
            rows.add(
                WidgetRow(
                    stableId = ("task|$id").hashCode().toLong(),
                    taskId = id,
                    title = displayTitle,
                    done = done == "1",
                    toggleDone = toggle,
                    hasChecklist = checklistCount > 0,
                    isChecklistChild = false,
                )
            )
            if (isExpanded) {
                for (j in 0 until checklistCount) {
                    val childText = prefs.getString("today_task_${i}_checklist_${j}_text", "") ?: ""
                    if (childText.isBlank()) continue
                    val childDone = prefs.getString("today_task_${i}_checklist_${j}_is_done", "0") == "1"
                    rows.add(
                        WidgetRow(
                            stableId = ("check|$id|$j").hashCode().toLong(),
                            taskId = id,
                            title = "• $childText",
                            done = childDone,
                            toggleDone = if (childDone) "0" else "1",
                            hasChecklist = false,
                            isChecklistChild = true,
                            checklistIndex = j,
                        )
                    )
                }
            }
        }
    }

    private data class WidgetRow(
        val stableId: Long,
        val taskId: String,
        val title: String,
        val done: Boolean,
        val toggleDone: String,
        val hasChecklist: Boolean,
        val isChecklistChild: Boolean,
        val checklistIndex: Int? = null,
    )
}
