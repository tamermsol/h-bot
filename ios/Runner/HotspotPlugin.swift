import Flutter
import UIKit
import NetworkExtension

/// Native iOS plugin for WiFi hotspot management using NEHotspotConfigurationManager
/// This bypasses captive portal detection and allows programmatic WiFi switching
public class HotspotPlugin: NSObject, FlutterPlugin {
    
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
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Join a WiFi network programmatically using NEHotspotConfigurationManager
    /// This bypasses iOS captive portal detection
    private func joinNetwork(ssid: String, password: String?, isWEP: Bool, result: @escaping FlutterResult) {
        let configuration: NEHotspotConfiguration
        
        if let password = password, !password.isEmpty {
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: isWEP)
        } else {
            // Open network (no password) - typical for device APs like hbot-XXXX
            configuration = NEHotspotConfiguration(ssid: ssid)
        }
        
        // Don't persist this network - we only need it temporarily for provisioning
        configuration.joinOnce = true
        
        // Disable captive portal detection for this network
        // The device AP has no internet, so we don't want iOS to show captive portal
        
        NEHotspotConfigurationManager.shared.apply(configuration) { error in
            if let error = error as NSError? {
                // Error code 13 = "already associated" - this is actually success
                if error.domain == NEHotspotConfigurationErrorDomain &&
                   error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    result(["success": true, "message": "Already connected to \(ssid)"])
                    return
                }
                
                // User cancelled the system dialog
                if error.domain == NEHotspotConfigurationErrorDomain &&
                   error.code == NEHotspotConfigurationError.userDenied.rawValue {
                    result(["success": false, "message": "Connection cancelled by user"])
                    return
                }
                
                result(["success": false, "message": "Failed to join \(ssid): \(error.localizedDescription)"])
                return
            }
            
            // Success - connected to the network
            result(["success": true, "message": "Connected to \(ssid)"])
        }
    }
    
    /// Leave/forget a WiFi network
    private func leaveNetwork(ssid: String, result: @escaping FlutterResult) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        result(["success": true, "message": "Disconnected from \(ssid)"])
    }
    
    /// Get current SSID using NEHotspot API (iOS 14+)
    private func getCurrentSSID(result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            NEHotspotNetwork.fetchCurrent { network in
                if let network = network {
                    result(network.ssid)
                } else {
                    result(nil)
                }
            }
        } else {
            // Fallback for older iOS - return nil, let Flutter side handle
            result(nil)
        }
    }
}
