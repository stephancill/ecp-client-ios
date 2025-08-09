//
//  ecp_clientApp.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import CoinbaseWalletSDK
import UserNotifications

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var notificationService: NotificationService?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Allow showing notifications while app is in foreground
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationService?.handleSuccessfulRegistration(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationService?.handleFailedRegistration(error: error)
    }

    // Show banner/list/sound while app is foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct ecp_clientApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var notificationService: NotificationService
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Configure Coinbase Wallet SDK with the selected wallet
        WalletConfigurationService.shared.configureCoinbaseSDK()
        WalletConfigurationService.shared.markWalletAsConfigured()
        
        // Initialize notification service with auth service
        let authSvc = AuthService()
        let notificationSvc = NotificationService(authService: authSvc)
        self._authService = StateObject(wrappedValue: authSvc)
        self._notificationService = StateObject(wrappedValue: notificationSvc)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    handleDeeplink(url: url)
                }
                .onAppear {
                    // Connect app delegate to notification service
                    appDelegate.notificationService = notificationService
                    
                    // Attempt authentication on app startup
                    Task {
                        if !authService.isAuthenticated {
                            await authService.authenticate()
                        }
                        
                        // Check notification status after authentication
                        await notificationService.checkNotificationStatus()
                    }
                }
        }
    }
    
    private func handleDeeplink(url: URL) {
        // First, try to handle Coinbase Wallet SDK response
        if (try? CoinbaseWalletSDK.shared.handleResponse(url)) == true {
            return
        }
        
        // Handle other types of deep links here
        print("Received deeplink: \(url)")
        
        // Example: Add your custom deeplink handling
        // if url.scheme == "ecp-client" {
        //     switch url.host {
        //     case "comment":
        //         let commentId = url.pathComponents.last
        //         // Navigate to specific comment
        //     case "user":
        //         let userId = url.pathComponents.last
        //         // Navigate to user profile
        //     default:
        //         break
        //     }
        // }
    }
}
