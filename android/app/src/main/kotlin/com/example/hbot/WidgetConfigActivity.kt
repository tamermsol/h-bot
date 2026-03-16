package com.example.hbot

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native Android widget configuration activity.
 * Opens when user adds the widget or taps "Settings" on it.
 * Reads available devices from SharedPreferences (saved by Flutter),
 * lets user pick up to 4 devices, saves selection.
 */
class WidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val selectedDeviceIds = mutableListOf<String>()
    private val allDevices = mutableListOf<JSONObject>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set result CANCELED in case user backs out
        setResult(RESULT_CANCELED)

        // Get widget ID
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Load devices from SharedPreferences
        loadDevices()

        // Load previously selected devices
        loadSelectedDevices()

        // Build the UI
        buildUI()
    }

    private fun loadDevices() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("all_devices_json", null) ?: return

        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                allDevices.add(arr.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadSelectedDevices() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        // Load from widget_favorites
        val favJson = prefs.getString("widget_favorites", null)
        if (favJson != null) {
            try {
                val arr = JSONArray(favJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    selectedDeviceIds.add(obj.getString("id"))
                }
            } catch (_: Exception) {}
        } else {
            // Fall back to currently shown devices
            val count = prefs.getInt("device_count", 0)
            for (i in 0 until count) {
                val id = prefs.getString("device_${i}_id", null)
                if (id != null) selectedDeviceIds.add(id)
            }
        }
    }

    private fun buildUI() {
        val bgColor = Color.parseColor("#1A1A2E")
        val cardColor = Color.parseColor("#252540")
        val accentColor = Color.parseColor("#10B981")
        val textColor = Color.WHITE
        val subtextColor = Color.parseColor("#99FFFFFF")

        // Root layout
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgColor)
            setPadding(0, 0, 0, 0)
        }

        // Status bar spacer
        val statusBarHeight = getStatusBarHeight()
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, statusBarHeight)
        })

        // Header bar
        val headerBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }

        val backBtn = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(textColor)
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dp(8), dp(8), dp(8), dp(8))
            setOnClickListener { finish() }
        }
        headerBar.addView(backBtn, LinearLayout.LayoutParams(dp(40), dp(40)))

        val title = TextView(this).apply {
            text = "Choose Devices"
            setTextColor(textColor)
            textSize = 20f
            setPadding(dp(12), 0, 0, 0)
        }
        headerBar.addView(title, LinearLayout.LayoutParams(0,
            ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        root.addView(headerBar)

        // Subtitle
        val subtitle = TextView(this).apply {
            text = "Select up to 4 devices for your widget"
            setTextColor(subtextColor)
            textSize = 14f
            setPadding(dp(20), dp(4), dp(20), dp(12))
        }
        root.addView(subtitle)

        if (allDevices.isEmpty()) {
            // Empty state
            val emptyText = TextView(this).apply {
                text = "No devices found.\nOpen the H-Bot app first to load your devices."
                setTextColor(subtextColor)
                textSize = 15f
                gravity = Gravity.CENTER
                setPadding(dp(32), dp(64), dp(32), dp(64))
            }
            root.addView(emptyText, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT))
        } else {
            // Scrollable device list
            val scrollView = ScrollView(this).apply {
                setPadding(dp(12), 0, dp(12), 0)
            }
            val listLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }

            for (device in allDevices) {
                val deviceId = device.optString("id", "")
                val deviceName = device.optString("name", "Device")
                val deviceType = device.optString("type", "switch")
                val channels = device.optInt("channels", 1)

                val card = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(14), dp(14), dp(14), dp(14))
                    val params = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT
                    ).apply { setMargins(dp(4), dp(4), dp(4), dp(4)) }
                    layoutParams = params
                }

                val isSelected = selectedDeviceIds.contains(deviceId)
                card.setBackgroundColor(if (isSelected) Color.parseColor("#1A10B981") else cardColor)

                // Device icon
                val iconText = TextView(this).apply {
                    text = when {
                        deviceType.contains("shutter", true) || deviceType.contains("blind", true) -> "🪟"
                        deviceType.contains("light", true) || deviceType.contains("dimmer", true) -> "💡"
                        else -> "⚡"
                    }
                    textSize = 22f
                    setPadding(dp(4), 0, dp(12), 0)
                }
                card.addView(iconText)

                // Name + type column
                val nameCol = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0,
                        ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                }

                val nameText = TextView(this).apply {
                    text = deviceName
                    setTextColor(textColor)
                    textSize = 15f
                }
                nameCol.addView(nameText)

                val typeText = TextView(this).apply {
                    text = "$deviceType • ${channels}ch"
                    setTextColor(subtextColor)
                    textSize = 12f
                }
                nameCol.addView(typeText)

                card.addView(nameCol)

                // Selection badge
                val badge = TextView(this).apply {
                    val idx = selectedDeviceIds.indexOf(deviceId)
                    if (idx >= 0) {
                        text = "${idx + 1}"
                        setTextColor(Color.WHITE)
                        textSize = 14f
                        gravity = Gravity.CENTER
                        setBackgroundColor(accentColor)
                        setPadding(dp(2), dp(2), dp(2), dp(2))
                        val p = LinearLayout.LayoutParams(dp(28), dp(28))
                        layoutParams = p
                    } else {
                        text = ""
                        setBackgroundColor(Color.parseColor("#33FFFFFF"))
                        val p = LinearLayout.LayoutParams(dp(28), dp(28))
                        layoutParams = p
                    }
                }
                card.addView(badge)

                card.setOnClickListener {
                    if (selectedDeviceIds.contains(deviceId)) {
                        selectedDeviceIds.remove(deviceId)
                    } else if (selectedDeviceIds.size < 4) {
                        selectedDeviceIds.add(deviceId)
                    } else {
                        Toast.makeText(this, "Maximum 4 devices", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }
                    // Rebuild UI to update badges
                    root.removeAllViews()
                    buildUI()
                }

                listLayout.addView(card)
            }

            scrollView.addView(listLayout)
            root.addView(scrollView, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }

        // Save button
        val saveBtn = Button(this).apply {
            text = if (selectedDeviceIds.isEmpty()) "Cancel" else "Save (${selectedDeviceIds.size} devices)"
            setTextColor(Color.WHITE)
            setBackgroundColor(if (selectedDeviceIds.isNotEmpty()) accentColor else Color.parseColor("#555555"))
            textSize = 16f
            isAllCaps = false
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(52)
            ).apply { setMargins(dp(16), dp(8), dp(16), dp(24)) }
            layoutParams = params

            setOnClickListener {
                if (selectedDeviceIds.isNotEmpty()) {
                    saveSelection()
                }
                finish()
            }
        }
        root.addView(saveBtn)

        setContentView(root)
    }

    private fun saveSelection() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // Build selected devices list
        val selectedDevices = JSONArray()
        var idx = 0
        for (deviceId in selectedDeviceIds) {
            val device = allDevices.find { it.optString("id") == deviceId } ?: continue

            // Save to widget data slots
            editor.putString("device_${idx}_id", device.optString("id"))
            editor.putString("device_${idx}_name", device.optString("name"))
            editor.putString("device_${idx}_state", if (device.optBoolean("isOn", false)) "ON" else "OFF")
            editor.putString("device_${idx}_type", device.optString("type", "switch"))
            editor.putString("device_${idx}_topic", device.optString("topicBase", ""))
            editor.putString("device_${idx}_channels", device.optInt("channels", 1).toString())

            selectedDevices.put(device)
            idx++
        }
        editor.putInt("device_count", idx)

        // Also save as widget_favorites for Flutter to read
        editor.putString("widget_favorites", selectedDevices.toString())
        editor.apply()

        // Trigger widget update
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)

        // Force update
        val updateIntent = Intent(this, HBotDeviceWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        sendBroadcast(updateIntent)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else dp(24)
    }
}
