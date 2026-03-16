package com.example.hbot

import android.appwidget.AppWidgetManager
import android.content.Context
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
                
                val deviceCount = widgetData.getInt("device_count", 0)
                var onlineCount = 0

                for (i in 0 until 4) {
                    val nameId = context.resources.getIdentifier("device_${i}_name", "id", context.packageName)
                    val toggleId = context.resources.getIdentifier("device_${i}_toggle", "id", context.packageName)
                    val indicatorId = context.resources.getIdentifier("device_${i}_indicator", "id", context.packageName)
                    val rowId = context.resources.getIdentifier("device_$i", "id", context.packageName)

                    if (i < deviceCount) {
                        val name = widgetData.getString("device_${i}_name", "Device ${i + 1}") ?: "Device ${i + 1}"
                        val state = widgetData.getString("device_${i}_state", "OFF") ?: "OFF"
                        val deviceId = widgetData.getString("device_${i}_id", "") ?: ""
                        val isOn = state == "ON"
                        if (isOn) onlineCount++

                        setViewVisibility(rowId, View.VISIBLE)
                        setTextViewText(nameId, name)

                        // Toggle button
                        setTextViewText(toggleId, if (isOn) "ON" else "OFF")
                        setInt(toggleId, "setBackgroundColor",
                            if (isOn) 0xFF10B981.toInt() else 0xFFD1D5DB.toInt())
                        setTextColor(toggleId,
                            if (isOn) 0xFFFFFFFF.toInt() else 0xFF6B7280.toInt())

                        // Status indicator dot
                        setInt(indicatorId, "setBackgroundColor",
                            if (isOn) 0xFF10B981.toInt() else 0xFFD1D5DB.toInt())

                        // Click opens app with device context
                        if (deviceId.isNotEmpty()) {
                            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
                                Uri.parse("hbot://toggle/$deviceId")
                            )
                            setOnClickPendingIntent(toggleId, pendingIntent)
                            setOnClickPendingIntent(rowId, pendingIntent)
                        }
                    } else {
                        setViewVisibility(rowId, View.GONE)
                    }
                }

                // Header status
                val statusId = context.resources.getIdentifier("widget_status", "id", context.packageName)
                if (deviceCount > 0) {
                    setTextViewText(statusId, "$onlineCount/$deviceCount ON")
                } else {
                    setTextViewText(statusId, "Open app to sync")
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
