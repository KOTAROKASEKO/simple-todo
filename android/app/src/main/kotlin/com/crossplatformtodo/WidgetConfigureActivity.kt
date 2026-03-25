package com.crossplatformtodo

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RadioGroup
import android.widget.SeekBar
import android.widget.TextView

class WidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var isDark = true
    private var opacity = 100

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        loadExistingPrefs()
        setContentView(R.layout.widget_configure_activity)
        setupUI()
    }

    private fun loadExistingPrefs() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isDark = prefs.getBoolean(prefKey(appWidgetId, KEY_IS_DARK), true)
        opacity = prefs.getInt(prefKey(appWidgetId, KEY_OPACITY), 100)
    }

    private fun setupUI() {
        val themeGroup = findViewById<RadioGroup>(R.id.theme_radio_group)
        val opacitySeekbar = findViewById<SeekBar>(R.id.opacity_seekbar)
        val opacityLabel = findViewById<TextView>(R.id.opacity_label)
        val saveButton = findViewById<Button>(R.id.save_button)

        if (isDark) {
            themeGroup.check(R.id.theme_dark)
        } else {
            themeGroup.check(R.id.theme_light)
        }
        opacitySeekbar.progress = opacity
        opacityLabel.text = "$opacity%"

        updatePreview()

        themeGroup.setOnCheckedChangeListener { _, checkedId ->
            isDark = checkedId == R.id.theme_dark
            updatePreview()
        }

        opacitySeekbar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                opacity = progress
                opacityLabel.text = "$progress%"
                updatePreview()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        saveButton.setOnClickListener {
            savePrefs()
            triggerWidgetUpdate()
            val resultValue = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }

    private fun updatePreview() {
        val previewWidget = findViewById<LinearLayout>(R.id.preview_widget)
        val previewContainer = findViewById<FrameLayout>(R.id.preview_container)
        val previewTitle = findViewById<TextView>(R.id.preview_title)
        val previewTask1 = findViewById<TextView>(R.id.preview_task1)
        val previewTask2 = findViewById<TextView>(R.id.preview_task2)

        val alpha = (opacity / 100f * 255).toInt().coerceIn(0, 255)

        val radius = 24f * resources.displayMetrics.density
        if (isDark) {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = radius
                setColor(Color.argb(alpha, 0, 0, 0))
            }
            previewWidget.background = bg
            previewTitle.setTextColor(Color.parseColor("#F9FAFB"))
            previewTask1.setTextColor(Color.parseColor("#E5E7EB"))
            previewTask2.setTextColor(Color.parseColor("#6B7280"))
            previewContainer.setBackgroundColor(Color.parseColor("#1A1A1A"))
        } else {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = radius
                setColor(Color.argb(alpha, 255, 255, 255))
            }
            previewWidget.background = bg
            previewTitle.setTextColor(Color.parseColor("#111827"))
            previewTask1.setTextColor(Color.parseColor("#374151"))
            previewTask2.setTextColor(Color.parseColor("#6B7280"))
            previewContainer.setBackgroundColor(Color.parseColor("#E5E7EB"))
        }
    }

    private fun savePrefs() {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
            putBoolean(prefKey(appWidgetId, KEY_IS_DARK), isDark)
            putInt(prefKey(appWidgetId, KEY_OPACITY), opacity)
            apply()
        }
    }

    private fun triggerWidgetUpdate() {
        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            val ids = intArrayOf(appWidgetId)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            setClass(this@WidgetConfigureActivity, TodoTodayWidgetProvider::class.java)
        }
        sendBroadcast(intent)
    }

    companion object {
        const val PREFS_NAME = "WidgetAppearancePrefs"
        private const val KEY_IS_DARK = "is_dark"
        private const val KEY_OPACITY = "opacity"

        fun prefKey(widgetId: Int, key: String): String = "widget_${widgetId}_$key"

        fun isDarkTheme(context: Context, widgetId: Int): Boolean {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(prefKey(widgetId, KEY_IS_DARK), true)
        }

        fun getOpacity(context: Context, widgetId: Int): Int {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getInt(prefKey(widgetId, KEY_OPACITY), 100)
        }

        fun deletePrefs(context: Context, widgetId: Int) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
                remove(prefKey(widgetId, KEY_IS_DARK))
                remove(prefKey(widgetId, KEY_OPACITY))
                apply()
            }
        }
    }
}
