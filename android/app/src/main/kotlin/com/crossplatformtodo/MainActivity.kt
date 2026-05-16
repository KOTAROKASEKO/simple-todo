package com.crossplatformtodo

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyFullScreenAlarmWindowFlags()
    }

    override fun onResume() {
        super.onResume()
        // Re-apply for the case where the activity is resumed due to a
        // full-screen-intent notification while the device is locked.
        applyFullScreenAlarmWindowFlags()
    }

    /**
     * Ensures the activity can appear over the lock screen and wakes the
     * device when launched via a super-important alarm full-screen intent.
     *
     * Uses the modern Activity APIs (O_MR1+) instead of deprecated window
     * flags where possible, and asks the KeyguardManager to dismiss the
     * non-secure keyguard when the alarm fires.
     */
    private fun applyFullScreenAlarmWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    or android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                    or android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
}
