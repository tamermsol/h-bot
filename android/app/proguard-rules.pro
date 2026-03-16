# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Flutter local notifications
-keep class com.dexterous.** { *; }

# Keep home_widget
-keep class es.antonborri.home_widget.** { *; }

# Keep Gson (used by some plugins)
-keepattributes Signature
-keepattributes *Annotation*

# Supabase / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Play Core split compat
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication

# Keep our widget provider and toggle receiver
-keep class com.example.hbot.HBotDeviceWidget { *; }
-keep class com.example.hbot.WidgetToggleReceiver { *; }

# Eclipse Paho MQTT
-keep class org.eclipse.paho.client.mqttv3.** { *; }
-dontwarn org.eclipse.paho.client.mqttv3.**
