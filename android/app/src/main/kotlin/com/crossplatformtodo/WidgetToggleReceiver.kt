package com.crossplatformtodo

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Source
import com.google.firebase.firestore.SetOptions
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin

class WidgetToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        val host = uri.host?.lowercase()
        if (host == "expand") {
            val taskId = uri.getQueryParameter("taskId") ?: return
            val widgetId = uri.getQueryParameter("widgetId")?.toIntOrNull()
                ?: AppWidgetManager.INVALID_APPWIDGET_ID
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                return
            }
            toggleExpandedTask(context, widgetId, taskId)
            refreshListViewOnly(context)
            return
        }
        if (host == "togglechecklist") {
            val taskId = uri.getQueryParameter("taskId") ?: return
            val checklistIndex = uri.getQueryParameter("index")?.toIntOrNull() ?: return
            val done = uri.getQueryParameter("done") ?: return
            val shouldMarkDone = done == "1"
            val isRecurring = resolveIsRecurring(context, taskId)

            vibrate(context)
            applyChecklistToggleToPrefs(context, taskId, checklistIndex, shouldMarkDone)
            refreshListViewOnly(context)
            syncChecklistToFirestore(context, taskId, checklistIndex, shouldMarkDone, isRecurring)
            return
        }
        if (host == "noop") {
            return
        }
        if (host != "toggle") {
            forwardToBackground(context, intent)
            return
        }

        val taskId = uri.getQueryParameter("taskId") ?: return
        val done = uri.getQueryParameter("done") ?: return
        val shouldMarkDone = done == "1"

        vibrate(context)

        val isRecurring = resolveIsRecurring(context, taskId)
        applyToggleToPrefs(context, taskId, shouldMarkDone)
        refreshListViewOnly(context)
        syncToFirestore(context, taskId, shouldMarkDone, isRecurring)
    }

    private fun resolveIsRecurring(context: Context, taskId: String): Boolean {
        val prefs = HomeWidgetPlugin.getData(context)
        val taskCount = prefs.getString("today_task_count", "0")?.toIntOrNull() ?: 0
        for (i in 0 until taskCount) {
            val currentId = prefs.getString("today_task_${i}_id", "") ?: ""
            if (currentId == taskId) {
                return prefs.getString("today_task_${i}_is_recurring", "0") == "1"
            }
        }
        return false
    }

    private fun applyToggleToPrefs(context: Context, taskId: String, shouldMarkDone: Boolean) {
        val prefs = HomeWidgetPlugin.getData(context)
        val taskCount = prefs.getString("today_task_count", "0")?.toIntOrNull() ?: 0

        for (i in 0 until taskCount) {
            val currentId = prefs.getString("today_task_${i}_id", "") ?: ""
            if (currentId != taskId) continue

            prefs.edit().apply {
                putString("today_task_${i}_is_done", if (shouldMarkDone) "1" else "0")
                putString("today_task_${i}_toggle_done", if (shouldMarkDone) "0" else "1")
                commit()
            }
            return
        }
    }

    private fun toggleExpandedTask(context: Context, widgetId: Int, taskId: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        val key = "today_widget_${widgetId}_expanded_task_id"
        val current = prefs.getString(key, "") ?: ""
        prefs.edit().apply {
            putString(key, if (current == taskId) "" else taskId)
            commit()
        }
    }

    private fun syncToFirestore(context: Context, taskId: String, shouldMarkDone: Boolean, isRecurring: Boolean) {
        val prefs = HomeWidgetPlugin.getData(context)
        val uid = prefs.getString("today_uid", null)
        if (uid.isNullOrBlank()) return

        val pendingResult = goAsync()

        Thread {
            try {
                if (FirebaseApp.getApps(context).isEmpty()) {
                    FirebaseApp.initializeApp(context)
                }

                val db = FirebaseFirestore.getInstance()
                val taskRef = db.collection("todo").document(uid).collection("tasks").document(taskId)

                if (!isRecurring) {
                    taskRef.update("isDone", shouldMarkDone)
                        .addOnCompleteListener { pendingResult.finish() }
                } else {
                    val now = java.util.Calendar.getInstance()
                    val dayKey = String.format(
                        "%04d-%02d-%02d",
                        now.get(java.util.Calendar.YEAR),
                        now.get(java.util.Calendar.MONTH) + 1,
                        now.get(java.util.Calendar.DAY_OF_MONTH)
                    )
                    taskRef.set(
                        mapOf("doneByDate" to mapOf(dayKey to shouldMarkDone)),
                        SetOptions.merge()
                    ).addOnCompleteListener { pendingResult.finish() }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Firestore sync failed for $taskId", e)
                pendingResult.finish()
            }
        }.start()
    }

    private fun applyChecklistToggleToPrefs(
        context: Context,
        taskId: String,
        checklistIndex: Int,
        shouldMarkDone: Boolean,
    ) {
        if (checklistIndex < 0) return
        val prefs = HomeWidgetPlugin.getData(context)
        val taskCount = prefs.getString("today_task_count", "0")?.toIntOrNull() ?: 0

        for (i in 0 until taskCount) {
            val currentId = prefs.getString("today_task_${i}_id", "") ?: ""
            if (currentId != taskId) continue

            val checklistCount = prefs.getString("today_task_${i}_checklist_count", "0")?.toIntOrNull() ?: 0
            if (checklistIndex >= checklistCount) return

            prefs.edit().apply {
                putString(
                    "today_task_${i}_checklist_${checklistIndex}_is_done",
                    if (shouldMarkDone) "1" else "0"
                )
                val allDone = (0 until checklistCount).all { idx ->
                    val current = if (idx == checklistIndex) {
                        shouldMarkDone
                    } else {
                        prefs.getString("today_task_${i}_checklist_${idx}_is_done", "0") == "1"
                    }
                    current
                }
                putString("today_task_${i}_is_done", if (allDone) "1" else "0")
                putString("today_task_${i}_toggle_done", if (allDone) "0" else "1")
                commit()
            }
            return
        }
    }

    private fun syncChecklistToFirestore(
        context: Context,
        taskId: String,
        checklistIndex: Int,
        shouldMarkDone: Boolean,
        isRecurring: Boolean,
    ) {
        if (checklistIndex < 0) return
        val prefs = HomeWidgetPlugin.getData(context)
        val uid = prefs.getString("today_uid", null)
        if (uid.isNullOrBlank()) return

        val pendingResult = goAsync()
        Thread {
            try {
                if (FirebaseApp.getApps(context).isEmpty()) {
                    FirebaseApp.initializeApp(context)
                }

                val db = FirebaseFirestore.getInstance()
                val taskRef = db.collection("todo").document(uid).collection("tasks").document(taskId)
                val taskSnap = Tasks.await(taskRef.get(Source.SERVER))
                if (!taskSnap.exists()) {
                    pendingResult.finish()
                    return@Thread
                }
                val data = taskSnap.data ?: emptyMap<String, Any>()
                val rawChecklist = data["checklist"] as? List<*> ?: emptyList<Any>()
                if (checklistIndex >= rawChecklist.size) {
                    pendingResult.finish()
                    return@Thread
                }

                if (!isRecurring) {
                    val updatedChecklist = rawChecklist.mapIndexed { idx, entry ->
                        val m = (entry as? Map<*, *>) ?: emptyMap<String, Any>()
                        val text = (m["text"] as? String).orEmpty()
                        mapOf(
                            "text" to text,
                            "isDone" to if (idx == checklistIndex) shouldMarkDone else (m["isDone"] == true),
                        )
                    }
                    val allDone = updatedChecklist.all { (it["isDone"] as? Boolean) == true }
                    taskRef.update(
                        mapOf(
                            "checklist" to updatedChecklist,
                            "isDone" to allDone,
                        )
                    ).addOnCompleteListener { pendingResult.finish() }
                    return@Thread
                }

                val now = java.util.Calendar.getInstance()
                val dayKey = String.format(
                    "%04d-%02d-%02d",
                    now.get(java.util.Calendar.YEAR),
                    now.get(java.util.Calendar.MONTH) + 1,
                    now.get(java.util.Calendar.DAY_OF_MONTH),
                )

                val texts = rawChecklist.mapNotNull { entry ->
                    val m = entry as? Map<*, *> ?: return@mapNotNull null
                    (m["text"] as? String)?.takeIf { it.isNotBlank() }
                }
                if (checklistIndex >= texts.size) {
                    pendingResult.finish()
                    return@Thread
                }

                val checklistDoneByDate = data["checklistDoneByDate"] as? Map<*, *>
                val dayBoolsRaw = checklistDoneByDate?.get(dayKey) as? List<*>
                val doneByDate = data["doneByDate"] as? Map<*, *>
                val fallbackDayDone = doneByDate?.get(dayKey) == true
                val bools = MutableList(texts.size) { idx ->
                    val existing = dayBoolsRaw?.getOrNull(idx)
                    when (existing) {
                        is Boolean -> existing
                        else -> fallbackDayDone
                    }
                }
                bools[checklistIndex] = shouldMarkDone
                val allDone = bools.all { it }
                val template = texts.map { text ->
                    mapOf(
                        "text" to text,
                        "isDone" to false,
                    )
                }
                taskRef.update(
                    mapOf(
                        "checklist" to template,
                        "checklistDoneByDate.$dayKey" to bools,
                        "doneByDate.$dayKey" to allDone,
                    )
                ).addOnCompleteListener { pendingResult.finish() }
            } catch (e: Exception) {
                Log.e(TAG, "Checklist sync failed for $taskId", e)
                pendingResult.finish()
            }
        }.start()
    }

    private fun refreshListViewOnly(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, TodoTodayWidgetProvider::class.java)
        )
        for (id in widgetIds) {
            appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.widget_tasks_list)
        }
    }

    private fun forwardToBackground(context: Context, intent: Intent) {
        val forwardedIntent = Intent(intent).apply {
            setClass(context, HomeWidgetBackgroundReceiver::class.java)
            action = ACTION_HOME_WIDGET_BACKGROUND
        }
        context.sendBroadcast(forwardedIntent)
    }

    private fun vibrate(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(VibratorManager::class.java) ?: return
            manager.defaultVibrator.vibrate(
                VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
            )
            return
        }

        @Suppress("DEPRECATION")
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(35L)
        }
    }

    companion object {
        private const val TAG = "WidgetToggleReceiver"
        const val ACTION_WIDGET_TOGGLE = "com.crossplatformtodo.action.WIDGET_TOGGLE"
        private const val ACTION_HOME_WIDGET_BACKGROUND = "es.antonborri.home_widget.action.BACKGROUND"
    }
}
