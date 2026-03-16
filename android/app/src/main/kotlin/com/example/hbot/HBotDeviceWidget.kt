package com.example.hbot

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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

            for (i in 0 until 4) {
                val nameId = context.resources.getIdentifier("device_${i}_name", "id", context.packageName)
                val stateId = context.resources.getIdentifier("device_${i}_state", "id", context.packageName)
                val rowId = context.resources.getIdentifier("device_$i", "id", context.packageName)

                if (i < deviceCount) {
                    val name = widgetData.getString("device_${i}_name", "Device ${i + 1}") ?: "Device ${i + 1}"
                    val state = widgetData.getString("device_${i}_state", "OFF") ?: "OFF"

                    views.setViewVisibility(rowId, android.view.View.VISIBLE)
                    views.setTextViewText(nameId, name)
                    views.setTextViewText(stateId, state)
                    views.setTextColor(
                        stateId,
                        if (state == "ON") 0xFF10B981.toInt() else 0xFF9CA3AF.toInt()
                    )
                } else {
                    views.setViewVisibility(rowId, android.view.View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
