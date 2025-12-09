// AppDelegate.swift
// Replace (or merge) the AppDelegate in ios/Runner with this. Make sure file is included in the Runner target.

import Flutter
import UIKit
import FirebaseCore
import FirebaseAppCheck
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    // IAP helper (expects IAPManager.swift to exist in project)
    private let iapManager = IAPManager()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Firebase configuration
        FirebaseApp.configure()

        #if DEBUG
        // Use debug App Check provider in debug builds (remove in prod)
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)

        // Setup method channel for native receipt helper
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.pegumax.iap", binaryMessenger: controller.binaryMessenger)

            channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                guard let self = self else {
                    result(FlutterError(code: "iap_error", message: "IAP manager missing", details: nil))
                    return
                }

                switch call.method {
                case "getAppStoreReceipt":
                    // Try quick cached read first; if missing, perform a refresh (non-forced)
                    if let r = self.iapManager.loadAppStoreReceiptBase64(),
                       !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Return cached receipt immediately
                        result(r)
                    } else {
                        // Trigger refresh & return result asynchronously
                        self.iapManager.refreshReceiptAndReturnBase64(force: false) { res in
                            switch res {
                            case .success(let base64):
                                result(base64)
                            case .failure(let err):
                                // Provide structured error to Flutter
                                result(FlutterError(code: "receipt_refresh_failed", message: err.localizedDescription, details: nil))
                            }
                        }
                    }

                case "refreshAppStoreReceipt":
                    // Force a refresh (useful for Sandbox scenarios)
                    self.iapManager.refreshReceiptAndReturnBase64(force: true) { res in
                        switch res {
                        case .success(let base64):
                            result(base64)
                        case .failure(let err):
                            result(FlutterError(code: "receipt_refresh_failed", message: err.localizedDescription, details: nil))
                        }
                    }

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
            NSLog("DEBUG: AppDelegate - IAP method channel registered.")
        } else {
            // Log if channel wasn't attached
            NSLog("DEBUG: AppDelegate - rootViewController is not FlutterViewController; method channel not registered.")
        }

        // No custom StoreKit transaction observer here; let the plugin handle transactions.
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
