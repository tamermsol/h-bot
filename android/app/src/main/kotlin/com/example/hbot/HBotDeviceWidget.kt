package com.example.hbot

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HBotDeviceWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.hbot_device_widget).apply {

                // Tap header → open app
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_title, openAppIntent)
                setOnClickPendingIntent(R.id.widget_logo, openAppIntent)

                val deviceCount = widgetData.getInt("device_count", 0)
                var onlineCount = 0

                val rowIds = intArrayOf(R.id.device_0, R.id.device_1, R.id.device_2, R.id.device_3)
                val nameIds = intArrayOf(R.id.device_0_name, R.id.device_1_name, R.id.device_2_name, R.id.device_3_name)
                val iconIds = intArrayOf(R.id.device_0_icon, R.id.device_1_icon, R.id.device_2_icon, R.id.device_3_icon)
                val toggleIds = intArrayOf(R.id.device_0_toggle, R.id.device_1_toggle, R.id.device_2_toggle, R.id.device_3_toggle)
                val shutterUpIds = intArrayOf(R.id.device_0_shutter_up, R.id.device_1_shutter_up, R.id.device_2_shutter_up, R.id.device_3_shutter_up)
                val shutterDownIds = intArrayOf(R.id.device_0_shutter_down, R.id.device_1_shutter_down, R.id.device_2_shutter_down, R.id.device_3_shutter_down)

                for (i in 0 until 4) {
                    if (i < deviceCount) {
                        val name = widgetData.getString("device_${i}_name", "Device") ?: "Device"
                        val state = widgetData.getString("device_${i}_state", "OFF") ?: "OFF"
                        val deviceId = widgetData.getString("device_${i}_id", "") ?: ""
                        val type = widgetData.getString("device_${i}_type", "switch") ?: "switch"
                        val topic = widgetData.getString("device_${i}_topic", "") ?: ""
                        val channel = (widgetData.getString("device_${i}_channel", "0") ?: "0").toIntOrNull() ?: 0
                        val isOn = state == "ON"
                        val isShutter = type.contains("shutter", ignoreCase = true) || type.contains("blind", ignoreCase = true)
                        if (isOn) onlineCount++

                        setViewVisibility(rowIds[i], View.VISIBLE)
                        setTextViewText(nameIds[i], name)

                        // Device type icon
                        val iconRes = when {
                            isShutter -> R.drawable.device_icon_shutter
                            type.contains("light", ignoreCase = true) ||
                            type.contains("dimmer", ignoreCase = true) -> R.drawable.device_icon_light
                            else -> R.drawable.device_icon_switch
                        }
                        setImageViewResource(iconIds[i], iconRes)

                        // Name brightness based on state
                        setTextColor(nameIds[i],
                            if (isOn) 0xFFFFFFFF.toInt() else 0xAAFFFFFF.toInt())

                        if (isShutter) {
                            // Show shutter controls (up/down), hide toggle
                            setViewVisibility(toggleIds[i], View.GONE)
                            setViewVisibility(shutterUpIds[i], View.VISIBLE)
                            setViewVisibility(shutterDownIds[i], View.VISIBLE)

                            if (topic.isNotEmpty()) {
                                setOnClickPendingIntent(shutterUpIds[i],
                                    createNativeIntent(context, WidgetToggleReceiver.ACTION_SHUTTER, deviceId, topic, "direction", "up", i * 100 + 1))
                                setOnClickPendingIntent(shutterDownIds[i],
                                    createNativeIntent(context, WidgetToggleReceiver.ACTION_SHUTTER, deviceId, topic, "direction", "down", i * 100 + 2))
                            }
                        } else {
                            // Show toggle, hide shutter controls
                            setViewVisibility(toggleIds[i], View.VISIBLE)
                            setViewVisibility(shutterUpIds[i], View.GONE)
                            setViewVisibility(shutterDownIds[i], View.GONE)

                            setTextViewText(toggleIds[i], if (isOn) "ON" else "OFF")
                            setInt(toggleIds[i], "setBackgroundResource",
                                if (isOn) R.drawable.toggle_on_bg else R.drawable.toggle_off_bg)
                            setTextColor(toggleIds[i],
                                if (isOn) 0xFFFFFFFF.toInt() else 0x99FFFFFF.toInt())

                            if (topic.isNotEmpty()) {
                                val newState = if (isOn) "OFF" else "ON"
                                setOnClickPendingIntent(toggleIds[i],
                                    createNativeIntent(context, WidgetToggleReceiver.ACTION_TOGGLE, deviceId, topic, "state", newState, i * 100 + 3, channel))
                            }
                        }

                        // Name tap → open app to device
                        if (deviceId.isNotEmpty()) {
                            val deviceIntent = HomeWidgetLaunchIntent.getActivity(
                                context, MainActivity::class.java,
                                Uri.parse("hbot://device/$deviceId")
                            )
                            setOnClickPendingIntent(nameIds[i], deviceIntent)
                            setOnClickPendingIntent(iconIds[i], deviceIntent)
                        }
                    } else {
                        setViewVisibility(rowIds[i], View.GONE)
                    }
                }

                // Header status
                if (deviceCount > 0) {
                    setViewVisibility(R.id.widget_empty, View.GONE)
                    setTextViewText(R.id.widget_status, "$onlineCount ON")
                } else {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    setTextViewText(R.id.widget_status, "")
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun createNativeIntent(
        context: Context,
        action: String,
        deviceId: String,
        topic: String,
        extraKey: String,
        extraValue: String,
        requestCode: Int,
        channel: Int = 0
    ): PendingIntent {
        val intent = Intent(context, WidgetToggleReceiver::class.java).apply {
            this.action = action
            putExtra("deviceId", deviceId)
            putExtra("topic", topic)
            putExtra("channel", channel)
            putExtra(extraKey, extraValue)
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
