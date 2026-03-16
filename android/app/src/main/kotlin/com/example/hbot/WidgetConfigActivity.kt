package com.example.hbot

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.*
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native widget config activity with H-Bot design system.
 * Opens when user adds the widget or long-press → Settings.
 * Supports channel-level device selection (each slot = device + channel).
 */
class WidgetConfigActivity : Activity() {

    // ─── H-Bot Design Tokens ───────────────────────────────────────
    // Matches lib/theme/app_theme.dart exactly
    private val bgColor    = Color.parseColor("#FF010510")  // n950 (backgroundDark)
    private val cardColor  = Color.parseColor("#FF1A202B")  // n800 (cardDark)
    private val cardHover  = Color.parseColor("#FF252D3A")  // slightly lighter
    private val primary    = Color.parseColor("#FF0883FD")  // blue500 (primary)
    private val primaryBg  = Color.parseColor("#1A0883FD")  // primary at 10% opacity
    private val textWhite  = Color.parseColor("#FFFFFFFF")  // n0
    private val textSec    = Color.parseColor("#FFC7C9CC")  // textSecondaryDark
    private val textTert   = Color.parseColor("#FF7A8494")  // n500
    private val border     = Color.parseColor("#FF181B1F")  // borderDark
    private val green      = Color.parseColor("#FF10B981")  // accent green
    private val radius     = 16f  // standard card radius

    // ─── State ─────────────────────────────────────────────────────
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private data class SlotSelection(
        val deviceId: String,
        val deviceName: String,
        val channel: Int,        // 0 = all/bulk, 1-8 = specific channel
        val channelLabel: String,
        val type: String,
        val topic: String,
        val totalChannels: Int
    )
    private val selectedSlots = mutableListOf<SlotSelection>()
    private val allDevices = mutableListOf<JSONObject>()
    private val expandedDeviceIds = mutableSetOf<String>()
    private var rootLayout: LinearLayout? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        // Make status bar transparent
        window.apply {
            addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            statusBarColor = bgColor
        }

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        loadDevices()
        loadSelectedSlots()
        rebuildUI()
    }

    // ─── Data Loading ──────────────────────────────────────────────

    private fun loadDevices() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("all_devices_json", null) ?: return
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) allDevices.add(arr.getJSONObject(i))
        } catch (_: Exception) {}
    }

    private fun loadSelectedSlots() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val json = prefs.getString("widget_slots_json", null) ?: return
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                selectedSlots.add(SlotSelection(
                    deviceId = obj.getString("deviceId"),
                    deviceName = obj.getString("deviceName"),
                    channel = obj.getInt("channel"),
                    channelLabel = obj.getString("channelLabel"),
                    type = obj.getString("type"),
                    topic = obj.getString("topic"),
                    totalChannels = obj.optInt("totalChannels", 1)
                ))
            }
        } catch (_: Exception) {}
    }

    // ─── UI Building ───────────────────────────────────────────────

    private fun rebuildUI() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgColor)
        }
        rootLayout = root

        // Status bar spacer
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, getStatusBarHeight())
        })

        // ── Header ──
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(8))
        }

        // Back button
        val backBtn = TextView(this).apply {
            text = "✕"
            setTextColor(textSec)
            textSize = 20f
            gravity = Gravity.CENTER
            val p = LinearLayout.LayoutParams(dp(40), dp(40))
            layoutParams = p
            setOnClickListener { finish() }
        }
        header.addView(backBtn)

        // Title
        val title = TextView(this).apply {
            text = "Widget Setup"
            setTextColor(textWhite)
            textSize = 20f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            setPadding(dp(8), 0, 0, 0)
            layoutParams = LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        header.addView(title)

        // Slot counter
        val counter = TextView(this).apply {
            text = "${selectedSlots.size}/4"
            setTextColor(if (selectedSlots.size > 0) primary else textTert)
            textSize = 16f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        header.addView(counter)

        root.addView(header)

        // Subtitle
        root.addView(TextView(this).apply {
            text = "Select up to 4 device channels for quick control"
            setTextColor(textSec)
            textSize = 14f
            setPadding(dp(64), 0, dp(20), dp(16))
        })

        // Thin divider
        root.addView(View(this).apply {
            setBackgroundColor(border)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(1))
        })

        // ── Device List ──
        if (allDevices.isEmpty()) {
            root.addView(buildEmptyState())
        } else {
            val scroll = ScrollView(this).apply {
                setPadding(dp(16), dp(8), dp(16), 0)
            }
            val list = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }

            for (device in allDevices) {
                list.addView(buildDeviceCard(device))
            }

            // Bottom padding for save button
            list.addView(View(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, dp(80))
            })

            scroll.addView(list)
            root.addView(scroll, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }

        // ── Save Button ──
        root.addView(buildSaveButton())

        setContentView(root)
    }

    private fun buildEmptyState(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(80), dp(32), dp(32))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)

            addView(TextView(this@WidgetConfigActivity).apply {
                text = "📱"
                textSize = 48f
                gravity = Gravity.CENTER
            })
            addView(TextView(this@WidgetConfigActivity).apply {
                text = "No Devices Found"
                setTextColor(textWhite)
                textSize = 18f
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                gravity = Gravity.CENTER
                setPadding(0, dp(16), 0, dp(8))
            })
            addView(TextView(this@WidgetConfigActivity).apply {
                text = "Open the H-Bot app first to load your devices, then come back here."
                setTextColor(textSec)
                textSize = 14f
                gravity = Gravity.CENTER
            })
        }
    }

    private fun buildDeviceCard(device: JSONObject): View {
        val deviceId = device.optString("id", "")
        val deviceName = device.optString("name", "Device")
        val deviceType = device.optString("type", "switch")
        val channels = device.optInt("channels", 1)
        val topic = device.optString("topicBase", "")
        val isExpanded = expandedDeviceIds.contains(deviceId)
        val isShutter = deviceType.contains("shutter", true) || deviceType.contains("blind", true)

        // Check if any channel of this device is selected
        val selectedChannelsForDevice = selectedSlots.filter { it.deviceId == deviceId }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = makeRoundedBg(
                if (selectedChannelsForDevice.isNotEmpty()) cardHover else cardColor,
                radius
            )
            val params = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, dp(4), 0, dp(4)) }
            layoutParams = params
        }

        // ── Device Header Row ──
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }

        // Device type icon
        val icon = TextView(this).apply {
            text = when {
                isShutter -> "🪟"
                deviceType.contains("light", true) || deviceType.contains("dimmer", true) -> "💡"
                else -> "⚡"
            }
            textSize = 24f
            setPadding(0, 0, dp(12), 0)
        }
        headerRow.addView(icon)

        // Name + channel count
        val nameCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        nameCol.addView(TextView(this).apply {
            text = deviceName
            setTextColor(textWhite)
            textSize = 15f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        })

        val channelLabel = when {
            isShutter -> "Shutter"
            channels <= 1 -> "Single channel"
            else -> "$channels channels"
        }
        val selectedLabel = if (selectedChannelsForDevice.isNotEmpty()) {
            " • ${selectedChannelsForDevice.size} selected"
        } else ""
        nameCol.addView(TextView(this).apply {
            text = "$channelLabel$selectedLabel"
            setTextColor(if (selectedChannelsForDevice.isNotEmpty()) primary else textTert)
            textSize = 12f
        })
        headerRow.addView(nameCol)

        // Expand arrow (only for multi-channel)
        if (channels > 1 && !isShutter) {
            headerRow.addView(TextView(this).apply {
                text = if (isExpanded) "▲" else "▼"
                setTextColor(textTert)
                textSize = 14f
            })
        }

        card.addView(headerRow)

        // For single-channel or shutter: tap header to toggle selection
        if (channels <= 1 || isShutter) {
            headerRow.setOnClickListener {
                toggleSlot(deviceId, deviceName, 0, deviceName, deviceType, topic, channels)
            }
        } else {
            // Multi-channel: tap header to expand/collapse
            headerRow.setOnClickListener {
                if (expandedDeviceIds.contains(deviceId)) {
                    expandedDeviceIds.remove(deviceId)
                } else {
                    expandedDeviceIds.add(deviceId)
                }
                rebuildUI()
            }

            // Show channel rows when expanded
            if (isExpanded) {
                // Divider
                card.addView(View(this).apply {
                    setBackgroundColor(border)
                    val p = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, dp(1))
                    p.setMargins(dp(16), 0, dp(16), 0)
                    layoutParams = p
                })

                // "All channels" option
                card.addView(buildChannelRow(
                    deviceId, deviceName, 0, "All channels (bulk)",
                    deviceType, topic, channels
                ))

                // Individual channels
                for (ch in 1..channels) {
                    card.addView(buildChannelRow(
                        deviceId, deviceName, ch, "Channel $ch",
                        deviceType, topic, channels
                    ))
                }
            }
        }

        return card
    }

    private fun buildChannelRow(
        deviceId: String, deviceName: String, channel: Int,
        label: String, type: String, topic: String, totalChannels: Int
    ): View {
        val isSelected = selectedSlots.any { it.deviceId == deviceId && it.channel == channel }
        val slotIndex = selectedSlots.indexOfFirst { it.deviceId == deviceId && it.channel == channel }

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(52), dp(10), dp(16), dp(10))
            if (isSelected) setBackgroundColor(primaryBg)
        }

        // Channel label
        row.addView(TextView(this).apply {
            text = label
            setTextColor(if (isSelected) textWhite else textSec)
            textSize = 14f
            layoutParams = LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        })

        // Selection badge
        if (isSelected) {
            row.addView(TextView(this).apply {
                text = "${slotIndex + 1}"
                setTextColor(Color.WHITE)
                textSize = 12f
                gravity = Gravity.CENTER
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                background = makeRoundedBg(primary, 12f)
                val p = LinearLayout.LayoutParams(dp(24), dp(24))
                layoutParams = p
            })
        } else {
            row.addView(View(this).apply {
                background = makeRoundedBg(Color.parseColor("#33FFFFFF"), 12f)
                val p = LinearLayout.LayoutParams(dp(24), dp(24))
                layoutParams = p
            })
        }

        row.setOnClickListener {
            val channelLabel = if (channel == 0) deviceName else "$deviceName CH$channel"
            toggleSlot(deviceId, deviceName, channel, channelLabel, type, topic, totalChannels)
        }

        return row
    }

    private fun buildSaveButton(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bgColor)
            setPadding(dp(16), dp(8), dp(16), dp(24))
        }

        val btn = TextView(this).apply {
            text = when {
                selectedSlots.isEmpty() -> "Cancel"
                selectedSlots.size == 1 -> "Save (1 control)"
                else -> "Save (${selectedSlots.size} controls)"
            }
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            background = makeRoundedBg(
                if (selectedSlots.isNotEmpty()) primary else Color.parseColor("#FF3D4A5C"),
                12f
            )
            val p = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(52))
            layoutParams = p
            setPadding(0, dp(14), 0, dp(14))

            setOnClickListener {
                if (selectedSlots.isNotEmpty()) saveSelection()
                finish()
            }
        }
        container.addView(btn)
        return container
    }

    // ─── Selection Logic ───────────────────────────────────────────

    private fun toggleSlot(
        deviceId: String, deviceName: String, channel: Int,
        channelLabel: String, type: String, topic: String, totalChannels: Int
    ) {
        val existing = selectedSlots.indexOfFirst { it.deviceId == deviceId && it.channel == channel }
        if (existing >= 0) {
            selectedSlots.removeAt(existing)
        } else if (selectedSlots.size < 4) {
            selectedSlots.add(SlotSelection(deviceId, deviceName, channel, channelLabel, type, topic, totalChannels))
        } else {
            Toast.makeText(this, "Maximum 4 controls", Toast.LENGTH_SHORT).show()
            return
        }
        rebuildUI()
    }

    // ─── Save ──────────────────────────────────────────────────────

    private fun saveSelection() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // Save as widget data for the widget provider to read
        editor.putInt("device_count", selectedSlots.size)
        val slotsJson = JSONArray()

        for ((idx, slot) in selectedSlots.withIndex()) {
            editor.putString("device_${idx}_id", slot.deviceId)
            editor.putString("device_${idx}_name", slot.channelLabel)
            editor.putString("device_${idx}_state", "OFF")
            editor.putString("device_${idx}_type", slot.type)
            editor.putString("device_${idx}_topic", slot.topic)
            editor.putString("device_${idx}_channels", slot.totalChannels.toString())
            editor.putString("device_${idx}_channel", slot.channel.toString())

            slotsJson.put(JSONObject().apply {
                put("deviceId", slot.deviceId)
                put("deviceName", slot.deviceName)
                put("channel", slot.channel)
                put("channelLabel", slot.channelLabel)
                put("type", slot.type)
                put("topic", slot.topic)
                put("totalChannels", slot.totalChannels)
            })
        }

        // Also save structured slots for reload
        editor.putString("widget_slots_json", slotsJson.toString())
        editor.apply()

        // Set result OK + trigger widget update
        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)

        val updateIntent = Intent(this, HBotDeviceWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        sendBroadcast(updateIntent)
    }

    // ─── Helpers ───────────────────────────────────────────────────

    private fun makeRoundedBg(color: Int, cornerRadius: Float): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            this.cornerRadius = dp(cornerRadius.toInt()).toFloat()
        }
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(),
            resources.displayMetrics).toInt()

    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else dp(24)
    }
}
