package com.example.hbot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.util.Log
import org.eclipse.paho.client.mqttv3.MqttClient
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.MqttMessage
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
import java.io.ByteArrayInputStream
import java.security.KeyStore
import java.security.cert.CertificateFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory
import kotlin.concurrent.thread

/**
 * Native Android BroadcastReceiver that handles widget toggle/shutter actions.
 * Sends MQTT commands via Paho MQTT client with TLS — no Flutter engine needed.
 */
class WidgetToggleReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TOGGLE = "com.example.hbot.WIDGET_TOGGLE"
        const val ACTION_SHUTTER = "com.example.hbot.WIDGET_SHUTTER"
        private const val TAG = "WidgetToggle"

        private const val BROKER = "ssl://y3ae1177.ala.eu-central-1.emqxsl.com:8883"
        private const val MQTT_USER = "admin"
        private const val MQTT_PASS = "P@ssword1"

        // DigiCert Global Root CA (same as assets/ca.crt)
        private const val CA_CERT = """-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97
nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P
T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4
gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO
BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR
TLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw
DQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr
hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg
06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF
PnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE-----"""
    }

    override fun onReceive(context: Context, intent: Intent) {
        val deviceId = intent.getStringExtra("deviceId") ?: return
        val topic = intent.getStringExtra("topic") ?: return
        val action = intent.action ?: return

        Log.d(TAG, "Received: action=$action deviceId=$deviceId topic=$topic")

        // Determine MQTT topic and payload
        val mqttTopic: String
        val mqttPayload: String

        when (action) {
            ACTION_TOGGLE -> {
                val newState = intent.getStringExtra("state") ?: "OFF"
                mqttTopic = "cmnd/$topic/POWER0"
                mqttPayload = newState

                // Update stored state for instant visual feedback
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                for (i in 0 until 4) {
                    val storedId = prefs.getString("device_${i}_id", null)
                    if (storedId == deviceId) {
                        editor.putString("device_${i}_state", newState)
                        break
                    }
                }
                editor.apply()
            }
            ACTION_SHUTTER -> {
                val direction = intent.getStringExtra("direction") ?: "stop"
                mqttTopic = "cmnd/$topic/ShutterPosition1"
                mqttPayload = when (direction) {
                    "up" -> "0"
                    "down" -> "100"
                    else -> "STOP"
                }
            }
            else -> return
        }

        // Refresh widget UI immediately
        refreshWidget(context)

        // Send MQTT in background thread (goAsync allows up to 10 seconds)
        val pendingResult = goAsync()
        thread {
            try {
                publishMqtt(mqttTopic, mqttPayload)
                Log.d(TAG, "✅ MQTT published: $mqttTopic = $mqttPayload")
            } catch (e: Exception) {
                Log.e(TAG, "❌ MQTT error: ${e.message}", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun refreshWidget(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val widgetComponent = ComponentName(context, HBotDeviceWidget::class.java)
        val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
        val updateIntent = Intent(context, HBotDeviceWidget::class.java).apply {
            this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
        }
        context.sendBroadcast(updateIntent)
    }

    private fun publishMqtt(topic: String, payload: String) {
        val clientId = "hbot-widget-${System.currentTimeMillis()}"
        val client = MqttClient(BROKER, clientId, MemoryPersistence())

        val options = MqttConnectOptions().apply {
            userName = MQTT_USER
            password = MQTT_PASS.toCharArray()
            connectionTimeout = 5
            isCleanSession = true
            socketFactory = createSslSocketFactory()
        }

        client.connect(options)
        val message = MqttMessage(payload.toByteArray()).apply {
            qos = 1
            isRetained = false
        }
        client.publish(topic, message)
        client.disconnect()
        client.close()
    }

    private fun createSslSocketFactory(): javax.net.ssl.SSLSocketFactory {
        val cf = CertificateFactory.getInstance("X.509")
        val caCert = cf.generateCertificate(ByteArrayInputStream(CA_CERT.toByteArray()))

        val keyStore = KeyStore.getInstance(KeyStore.getDefaultType())
        keyStore.load(null, null)
        keyStore.setCertificateEntry("ca", caCert)

        val tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        tmf.init(keyStore)

        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, tmf.trustManagers, null)
        return sslContext.socketFactory
    }
}
