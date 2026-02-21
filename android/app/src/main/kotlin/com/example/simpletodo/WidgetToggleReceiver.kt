package com.example.simpletodo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver

class WidgetToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.data?.host.equals("toggle", ignoreCase = true)) {
            vibrate(context)
        }

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
        const val ACTION_WIDGET_TOGGLE = "com.example.simpletodo.action.WIDGET_TOGGLE"
        private const val ACTION_HOME_WIDGET_BACKGROUND = "es.antonborri.home_widget.action.BACKGROUND"
    }
}
