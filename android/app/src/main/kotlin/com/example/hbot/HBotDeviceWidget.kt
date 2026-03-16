package com.example.hbot

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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
                val toggleIds = intArrayOf(R.id.device_0_toggle, R.id.device_1_toggle, R.id.device_2_toggle, R.id.device_3_toggle)
                val iconIds = intArrayOf(R.id.device_0_icon, R.id.device_1_icon, R.id.device_2_icon, R.id.device_3_icon)

                for (i in 0 until 4) {
                    if (i < deviceCount) {
                        val name = widgetData.getString("device_${i}_name", "Device") ?: "Device"
                        val state = widgetData.getString("device_${i}_state", "OFF") ?: "OFF"
                        val deviceId = widgetData.getString("device_${i}_id", "") ?: ""
                        val type = widgetData.getString("device_${i}_type", "switch") ?: "switch"
                        val isOn = state == "ON"
                        if (isOn) onlineCount++

                        setViewVisibility(rowIds[i], View.VISIBLE)
                        setTextViewText(nameIds[i], name)

                        // Device type icon
                        val iconRes = when {
                            type.contains("light", ignoreCase = true) || 
                            type.contains("dimmer", ignoreCase = true) -> R.drawable.device_icon_light
                            type.contains("shutter", ignoreCase = true) || 
                            type.contains("blind", ignoreCase = true) -> R.drawable.device_icon_shutter
                            else -> R.drawable.device_icon_switch
                        }
                        setImageViewResource(iconIds[i], iconRes)

                        // Toggle button — different drawable for on/off
                        setTextViewText(toggleIds[i], if (isOn) "ON" else "OFF")
                        setInt(toggleIds[i], "setBackgroundResource",
                            if (isOn) R.drawable.toggle_on_bg else R.drawable.toggle_off_bg)
                        setTextColor(toggleIds[i],
                            if (isOn) 0xFFFFFFFF.toInt() else 0x99FFFFFF.toInt())

                        // Name color: brighter if on
                        setTextColor(nameIds[i],
                            if (isOn) 0xFFFFFFFF.toInt() else 0xBBFFFFFF.toInt())

                        // Toggle click → background Dart callback
                        if (deviceId.isNotEmpty()) {
                            val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                                context,
                                Uri.parse("hbot://toggle?deviceId=$deviceId&state=${if (isOn) "OFF" else "ON"}")
                            )
                            setOnClickPendingIntent(toggleIds[i], toggleIntent)

                            // Row click → open app to device
                            val deviceIntent = HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
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
}
