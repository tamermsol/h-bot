package com.example.hbot

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

class EnhancedWiFiPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var wifiManager: WifiManager
    private lateinit var connectivityManager: ConnectivityManager

    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var boundNetwork: Network? = null
    private var connectionJob: Job? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "enhanced_wifi_service")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "scanForHbotAPs" -> scanForHbotAPs(result)
            "connectToHbotAPModern" -> connectToHbotAPModern(call, result)
            "connectToHbotAPLegacy" -> connectToHbotAPLegacy(call, result)
            "disconnectFromHbotAP" -> disconnectFromHbotAP(result)
            "reconnectToUserWifi" -> reconnectToUserWifi(call, result)
            "isBound" -> result.success(boundNetwork != null)
            "getCurrentWifi" -> getCurrentWifi(result)
            "isLocationEnabled" -> isLocationEnabled(result)
            else -> result.notImplemented()
        }
    }

    private fun scanForHbotAPs(result: Result) {
        try {
            if (!wifiManager.isWifiEnabled) {
                result.error("WIFI_DISABLED", "Wi-Fi is disabled", null)
                return
            }

            // Trigger a fresh scan first
            val scanStarted = wifiManager.startScan()
            if (!scanStarted) {
                Log.w("EnhancedWiFi", "Failed to start Wi-Fi scan")
            }

            // Wait a moment for scan to complete, then get results
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val scanResults = wifiManager.scanResults
                    val hbotAPs = scanResults
                        ?.filter {
                            val ssid = it.SSID
                            ssid != null && ssid.lowercase().startsWith("hbot") && ssid.isNotEmpty()
                        }
                        ?.map { it.SSID }
                        ?.distinct()
                        ?: emptyList()

                    Log.d("EnhancedWiFi", "Found ${hbotAPs.size} hbot networks: $hbotAPs")
                    result.success(hbotAPs)
                } catch (e: Exception) {
                    Log.e("EnhancedWiFi", "Error processing scan results", e)
                    result.error("SCAN_FAILED", "Failed to process scan results: ${e.message}", null)
                }
            }, 3000) // Wait 3 seconds for scan to complete

        } catch (e: Exception) {
            Log.e("EnhancedWiFi", "Error starting scan", e)
            result.error("SCAN_FAILED", "Failed to scan for networks: ${e.message}", null)
        }
    }

    private fun connectToHbotAPModern(call: MethodCall, result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("API_NOT_SUPPORTED", "Modern API requires Android 10+", null)
            return
        }

        val ssid = call.argument<String>("ssid")
        val timeout = call.argument<Int>("timeout") ?: 30000

        if (ssid == null) {
            result.error("INVALID_ARGS", "SSID is required", null)
            return
        }

        connectionJob?.cancel()
        connectionJob = CoroutineScope(Dispatchers.Main).launch {
            try {
                val success = connectUsingNetworkSpecifier(ssid, timeout.toLong())
                if (success) {
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Connected successfully",
                        "requiresManualConnection" to false
                    ))
                } else {
                    result.success(mapOf(
                        "success" to false,
                        "message" to "Connection timed out. Please connect manually.",
                        "requiresManualConnection" to true
                    ))
                }
            } catch (e: Exception) {
                result.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
            }
        }
    }

    private fun connectToHbotAPLegacy(call: MethodCall, result: Result) {
        val ssid = call.argument<String>("ssid")
        val timeout = call.argument<Int>("timeout") ?: 30000

        if (ssid == null) {
            result.error("INVALID_ARGS", "SSID is required", null)
            return
        }

        try {
            // For legacy Android, we'll guide user to manual connection
            // as programmatic connection is unreliable on older versions
            result.success(mapOf(
                "success" to false,
                "message" to "Please connect manually to $ssid in Wi-Fi settings",
                "requiresManualConnection" to true
            ))
        } catch (e: Exception) {
            result.error("CONNECTION_FAILED", "Failed to connect: ${e.message}", null)
        }
    }

    private suspend fun connectUsingNetworkSpecifier(ssid: String, timeoutMs: Long): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val specifier = WifiNetworkSpecifier.Builder()
                    .setSsid(ssid)
                    .build()

                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) // Critical: SoftAP has no internet
                    .setNetworkSpecifier(specifier)
                    .build()

                var connected = false
                var capturedNetwork: Network? = null

                val callback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        Log.d("EnhancedWiFi", "Network available: $network")
                        capturedNetwork = network

                        // CRITICAL FIX: Bind process to this network so HTTP calls go over SoftAP
                        val bindSuccess = connectivityManager.bindProcessToNetwork(network)
                        if (bindSuccess) {
                            boundNetwork = network
                            connected = true
                            Log.d("EnhancedWiFi", "Successfully bound to SoftAP network")
                        } else {
                            Log.e("EnhancedWiFi", "Failed to bind to SoftAP network")
                            connected = false
                        }

                        networkCallback = this
                    }

                    override fun onUnavailable() {
                        Log.w("EnhancedWiFi", "Network unavailable")
                        connected = false
                    }

                    override fun onLost(network: Network) {
                        Log.d("EnhancedWiFi", "Network lost: $network")
                        if (boundNetwork == network) {
                            try {
                                connectivityManager.bindProcessToNetwork(null)
                            } catch (e: Exception) {
                                Log.w("EnhancedWiFi", "Error unbinding on network lost: ${e.message}")
                            }
                            boundNetwork = null
                        }
                    }
                }

                connectivityManager.requestNetwork(request, callback)

                // Wait for connection with timeout
                val startTime = System.currentTimeMillis()
                while (!connected && (System.currentTimeMillis() - startTime) < timeoutMs) {
                    delay(500)
                }

                if (connected) {
                    Log.d("EnhancedWiFi", "Connection successful, network is bound")
                    // Give the network a moment to settle before HTTP calls
                    delay(1000)
                    Log.d("EnhancedWiFi", "Network ready for HTTP traffic")
                } else {
                    Log.w("EnhancedWiFi", "Connection timeout or failed")
                }

                connected
            } catch (e: Exception) {
                Log.e("EnhancedWiFi", "Error in connectUsingNetworkSpecifier", e)
                false
            }
        }
    }

    private fun disconnectFromHbotAP(result: Result) {
        try {
            Log.d("EnhancedWiFi", "Starting disconnection from hbot AP")

            // CRITICAL: Unbind from the SoftAP network first
            try {
                connectivityManager.bindProcessToNetwork(null)
                Log.d("EnhancedWiFi", "Process unbound from SoftAP network")
            } catch (e: Exception) {
                Log.w("EnhancedWiFi", "Failed to unbind process: ${e.message}")
            }
            boundNetwork = null

            // Unregister network callback if exists
            networkCallback?.let { callback ->
                try {
                    connectivityManager.unregisterNetworkCallback(callback)
                    Log.d("EnhancedWiFi", "Network callback unregistered")
                } catch (e: Exception) {
                    Log.w("EnhancedWiFi", "Failed to unregister network callback: ${e.message}")
                }
                networkCallback = null
            }

            // Cancel any ongoing connection job
            connectionJob?.cancel()
            connectionJob = null

            Log.d("EnhancedWiFi", "Disconnection completed successfully, system should reconnect to previous network")
            result.success(mapOf(
                "success" to true,
                "message" to "Disconnected from device AP"
            ))
        } catch (e: Exception) {
            Log.e("EnhancedWiFi", "Failed to disconnect from hbot AP", e)
            result.error("DISCONNECT_FAILED", "Failed to disconnect: ${e.message}", null)
        }
    }

    private fun isLocationEnabled(result: Result) {
        try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isEnabled = locationManager.isLocationEnabled
            result.success(isEnabled)
        } catch (e: Exception) {
            Log.w("EnhancedWiFi", "Error checking location status: ${e.message}")
            result.success(true) // Assume enabled if we can't check
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentWifi(result: Result) {
        try {
            // Try multiple methods to get SSID (Android 13+ can be tricky)
            var wifiInfo: WifiInfo? = null
            var ssid: String? = null

            // Method 1: Try getting from active network (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val activeNetwork = connectivityManager.activeNetwork
                if (activeNetwork != null) {
                    val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
                    if (capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                        wifiInfo = capabilities.transportInfo as? WifiInfo
                        if (wifiInfo != null) {
                            val rawSsid = wifiInfo.ssid
                            if (rawSsid != null && !rawSsid.equals("<unknown ssid>", ignoreCase = true) && rawSsid.isNotEmpty()) {
                                ssid = rawSsid.trim('"')
                                Log.d("EnhancedWiFi", "Got SSID from transportInfo: $ssid")
                            }
                        }
                    }
                }
            }

            // Method 2: Fallback to WifiManager.connectionInfo (works on Android 10-11, sometimes on 12+)
            if (ssid == null) {
                @Suppress("DEPRECATION")
                wifiInfo = wifiManager.connectionInfo
                if (wifiInfo != null) {
                    val rawSsid = wifiInfo.ssid
                    if (rawSsid != null && !rawSsid.equals("<unknown ssid>", ignoreCase = true) && rawSsid.isNotEmpty()) {
                        ssid = rawSsid.trim('"')
                        Log.d("EnhancedWiFi", "Got SSID from WifiManager.connectionInfo: $ssid")
                    }
                }
            }

            // Method 3: Try scanning for connected network (last resort for Android 13+)
            if (ssid == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                try {
                    val scanResults = wifiManager.scanResults
                    if (scanResults != null && scanResults.isNotEmpty()) {
                        // Find the network we're connected to by matching BSSID
                        @Suppress("DEPRECATION")
                        val currentBssid = wifiManager.connectionInfo?.bssid
                        if (currentBssid != null) {
                            val connectedNetwork = scanResults.find { it.BSSID == currentBssid }
                            if (connectedNetwork != null && connectedNetwork.SSID.isNotEmpty()) {
                                ssid = connectedNetwork.SSID
                                Log.d("EnhancedWiFi", "Got SSID from scan results: $ssid")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w("EnhancedWiFi", "Failed to get SSID from scan results: ${e.message}")
                }
            }

            // If still no SSID, return null
            if (ssid == null || wifiInfo == null) {
                Log.d("EnhancedWiFi", "Could not determine SSID (ssid=$ssid, wifiInfo=$wifiInfo)")
                result.success(null)
                return
            }

            // Get frequency to determine 2.4GHz vs 5GHz
            val frequency = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                wifiInfo.frequency
            } else {
                @Suppress("DEPRECATION")
                wifiInfo.frequency
            }
            val is24GHz = frequency in 2400..2500

            // Get IP address
            val ipInt = wifiInfo.ipAddress
            val ipStr = if (ipInt != 0) {
                String.format(
                    "%d.%d.%d.%d",
                    (ipInt and 0xff),
                    (ipInt shr 8 and 0xff),
                    (ipInt shr 16 and 0xff),
                    (ipInt shr 24 and 0xff)
                )
            } else {
                null
            }

            val bssid = wifiInfo.bssid

            Log.d("EnhancedWiFi", "Current Wi-Fi: SSID=$ssid, 2.4GHz=$is24GHz, IP=$ipStr")

            result.success(mapOf(
                "ssid" to ssid,
                "bssid" to bssid,
                "is24GHz" to is24GHz,
                "ip" to ipStr,
                "frequency" to frequency
            ))
        } catch (e: SecurityException) {
            Log.e("EnhancedWiFi", "Permission denied reading Wi-Fi info", e)
            result.error("PERMISSION_DENIED", "Location permission required to read Wi-Fi SSID", null)
        } catch (e: Exception) {
            Log.e("EnhancedWiFi", "Error reading Wi-Fi info", e)
            result.error("WIFI_READ_FAILED", "Failed to read Wi-Fi info: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)

        // Clean up network binding
        try {
            connectivityManager.bindProcessToNetwork(null)
        } catch (e: Exception) {
            Log.w("EnhancedWiFi", "Error unbinding on detach: ${e.message}")
        }
        boundNetwork = null

        networkCallback?.let { callback ->
            try {
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (e: Exception) {
                Log.w("EnhancedWiFi", "Error unregistering callback on detach: ${e.message}")
            }
        }
        connectionJob?.cancel()
    }

    /**
     * Reconnect to user's Wi-Fi network after provisioning device
     * Uses WifiNetworkSuggestion on API 29+ for automatic reconnection
     */
    @SuppressLint("MissingPermission")
    private fun reconnectToUserWifi(call: MethodCall, result: Result) {
        val ssid = call.argument<String>("ssid")
        val password = call.argument<String>("password")

        if (ssid == null || password == null) {
            result.error("INVALID_ARGS", "SSID and password are required", null)
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ (API 29+): Use WifiNetworkSuggestion
                Log.d("EnhancedWiFi", "Reconnecting to user Wi-Fi: $ssid using WifiNetworkSuggestion")

                val suggestion = WifiNetworkSuggestion.Builder()
                    .setSsid(ssid)
                    .setWpa2Passphrase(password)
                    .setIsAppInteractionRequired(false)  // Auto-connect without user interaction
                    .build()

                val status = wifiManager.addNetworkSuggestions(listOf(suggestion))

                when (status) {
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS -> {
                        Log.d("EnhancedWiFi", "Network suggestion added successfully")
                        result.success(mapOf(
                            "success" to true,
                            "message" to "Reconnecting to $ssid..."
                        ))
                    }
                    WifiManager.STATUS_NETWORK_SUGGESTIONS_ERROR_ADD_DUPLICATE -> {
                        Log.d("EnhancedWiFi", "Network suggestion already exists (duplicate)")
                        result.success(mapOf(
                            "success" to true,
                            "message" to "Network already configured, reconnecting..."
                        ))
                    }
                    else -> {
                        Log.e("EnhancedWiFi", "Failed to add network suggestion: status=$status")
                        result.error("SUGGESTION_FAILED", "Failed to add network suggestion: $status", null)
                    }
                }
            } else {
                // Android 9 and below: Use legacy WifiConfiguration
                Log.d("EnhancedWiFi", "Reconnecting to user Wi-Fi: $ssid using WifiConfiguration")

                val wifiConfig = WifiConfiguration().apply {
                    SSID = "\"$ssid\""
                    preSharedKey = "\"$password\""
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                }

                val netId = wifiManager.addNetwork(wifiConfig)
                if (netId == -1) {
                    result.error("ADD_NETWORK_FAILED", "Failed to add network configuration", null)
                    return
                }

                val enabled = wifiManager.enableNetwork(netId, true)
                if (!enabled) {
                    result.error("ENABLE_NETWORK_FAILED", "Failed to enable network", null)
                    return
                }

                val reconnected = wifiManager.reconnect()
                if (!reconnected) {
                    result.error("RECONNECT_FAILED", "Failed to reconnect", null)
                    return
                }

                Log.d("EnhancedWiFi", "Reconnection initiated successfully")
                result.success(mapOf(
                    "success" to true,
                    "message" to "Reconnecting to $ssid..."
                ))
            }
        } catch (e: Exception) {
            Log.e("EnhancedWiFi", "Error reconnecting to user Wi-Fi", e)
            result.error("RECONNECT_ERROR", "Failed to reconnect: ${e.message}", null)
        }
    }
}
