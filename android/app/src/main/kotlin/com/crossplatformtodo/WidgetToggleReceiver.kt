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
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin

class WidgetToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        if (!uri.host.equals("toggle", ignoreCase = true)) {
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
