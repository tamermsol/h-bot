import Flutter
import UIKit
import NetworkExtension
import SystemConfiguration.CaptiveNetwork
import CoreLocation

/// Native iOS plugin for WiFi hotspot management using NEHotspotConfigurationManager
/// This bypasses captive portal detection and allows programmatic WiFi switching
public class HotspotPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
    
    private var locationManager: CLLocationManager?
    private var preciseLocationResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.mb.hbot/hotspot", binaryMessenger: registrar.messenger())
        let instance = HotspotPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "joinNetwork":
            guard let args = call.arguments as? [String: Any],
                  let ssid = args["ssid"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing ssid", details: nil))
                return
            }
            let password = args["password"] as? String
            let isWEP = args["isWEP"] as? Bool ?? false
            joinNetwork(ssid: ssid, password: password, isWEP: isWEP, result: result)
            
        case "leaveNetwork":
            guard let args = call.arguments as? [String: Any],
                  let ssid = args["ssid"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing ssid", details: nil))
                return
            }
            leaveNetwork(ssid: ssid, result: result)
            
        case "getCurrentSSID":
            getCurrentSSID(result: result)
            
        case "requestPreciseLocation":
            requestPreciseLocation(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Join a WiFi network programmatically using NEHotspotConfigurationManager
    /// This bypasses iOS captive portal detection
    private func joinNetwork(ssid: String, password: String?, isWEP: Bool, result: @escaping FlutterResult) {
        // Step 1: Remove any stale configuration first to force a fresh join
        // This prevents false "alreadyAssociated" results from previous attempts
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        
        // Small delay after removal to let iOS clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let configuration: NEHotspotConfiguration
            
            if let password = password, !password.isEmpty {
                configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: isWEP)
            } else {
                // Open network (no password) - typical for device APs like hbot-XXXX
                configuration = NEHotspotConfiguration(ssid: ssid)
            }
            
            // joinOnce = true means iOS won't persist the config after disconnect
            configuration.joinOnce = true
            
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                if let error = error as NSError? {
                    // Error code 13 = "already associated"
                    // After removing config above, if we still get this, the device is genuinely connected
                    if error.domain == NEHotspotConfigurationErrorDomain &&
                       error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        result(["success": true, "message": "Already connected to \(ssid)"])
                        return
                    }
                    
                    // User cancelled the system dialog
                    if error.domain == NEHotspotConfigurationErrorDomain &&
                       error.code == NEHotspotConfigurationError.userDenied.rawValue {
                        result(["success": false, "message": "Connection cancelled by user. Please tap Join when prompted."])
                        return
                    }
                    
                    // Internal error - often means the network couldn't be found or associated
                    if error.domain == NEHotspotConfigurationErrorDomain &&
                       error.code == NEHotspotConfigurationError.internal.rawValue {
                        result(["success": false, "message": "iOS could not join \(ssid). The device may not be in pairing mode or is out of range. Try connecting manually via Settings > Wi-Fi."])
                        return
                    }
                    
                    result(["success": false, "message": "Failed to join \(ssid): \(error.localizedDescription) (code: \(error.code))"])
                    return
                }
                
                // Success - connected to the network
                // Note: Even with nil error, iOS may not route traffic through this network
                // if another network with internet is available. The caller should verify
                // reachability to 192.168.4.1 after a delay.
                result(["success": true, "message": "Connected to \(ssid)"])
            }
        }
    }
    
    /// Leave/forget a WiFi network
    private func leaveNetwork(ssid: String, result: @escaping FlutterResult) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        result(["success": true, "message": "Disconnected from \(ssid)"])
    }
    
    /// Get current SSID using NEHotspot API (iOS 14+) with CNCopyCurrentNetworkInfo fallback
    private func getCurrentSSID(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            NEHotspotNetwork.fetchCurrent { network in
                if let ssid = network?.ssid, !ssid.isEmpty {
                    result(ssid)
                    return
                }
                // Fallback to CNCopyCurrentNetworkInfo
                result(self.getSSIDViaCNC())
            }
        } else {
            result(self.getSSIDViaCNC())
        }
    }
    
    /// Fallback SSID detection using legacy CNCopyCurrentNetworkInfo API
    private func getSSIDViaCNC() -> String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
                  let ssid = info[kCNNetworkInfoKeySSID as String] as? String,
                  !ssid.isEmpty else { continue }
            return ssid
        }
        return nil
    }
    
    /// Request temporary full (precise) location accuracy — required for SSID reading on iOS 14+
    private func requestPreciseLocation(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            let manager = CLLocationManager()
            self.locationManager = manager
            manager.delegate = self
            
            switch manager.accuracyAuthorization {
            case .fullAccuracy:
                // Already have precise location
                result(true)
                return
            case .reducedAccuracy:
                // Request temporary full accuracy
                self.preciseLocationResult = result
                manager.requestTemporaryFullAccuracyAuthorization(purposeKey: "WifiSSIDRead") { error in
                    if let error = error {
                        self.preciseLocationResult?(false)
                        self.preciseLocationResult = nil
                        return
                    }
                    let granted = manager.accuracyAuthorization == .fullAccuracy
                    self.preciseLocationResult?(granted)
                    self.preciseLocationResult = nil
                }
            @unknown default:
                result(false)
            }
        } else {
            result(true) // Pre-iOS 14, no reduced accuracy concept
        }
    }
}
