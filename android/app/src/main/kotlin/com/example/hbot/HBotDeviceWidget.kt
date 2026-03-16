package com.example.hbot

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HBotDeviceWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.hbot_device_widget)

            val deviceCount = widgetData.getInt("device_count", 0)
            val onlineCount = (0 until deviceCount).count { i ->
                widgetData.getString("device_${i}_state", "OFF") == "ON"
            }
            
            // Status text
            val statusId = context.resources.getIdentifier("widget_status", "id", context.packageName)
            views.setTextViewText(statusId, "$onlineCount/$deviceCount ON")

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

                    views.setViewVisibility(rowId, android.view.View.VISIBLE)
                    views.setTextViewText(nameId, name)
                    
                    // Toggle button text and color
                    views.setTextViewText(toggleId, if (isOn) "ON" else "OFF")
                    views.setInt(toggleId, "setBackgroundColor", 
                        if (isOn) 0xFF10B981.toInt() else 0xFFD1D5DB.toInt())
                    views.setTextColor(toggleId,
                        if (isOn) 0xFFFFFFFF.toInt() else 0xFF6B7280.toInt())
                    
                    // Status indicator dot
                    views.setInt(indicatorId, "setBackgroundColor",
                        if (isOn) 0xFF10B981.toInt() else 0xFFD1D5DB.toInt())
                    
                    // Click to toggle — launches the app with toggle intent
                    if (deviceId.isNotEmpty()) {
                        val toggleIntent = Intent(context, MainActivity::class.java).apply {
                            action = "TOGGLE_DEVICE"
                            data = Uri.parse("hbot://toggle/$deviceId")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                        val pendingIntent = PendingIntent.getActivity(
                            context, i, toggleIntent, 
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(toggleId, pendingIntent)
                        views.setOnClickPendingIntent(rowId, pendingIntent)
                    }
                } else {
                    views.setViewVisibility(rowId, android.view.View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
