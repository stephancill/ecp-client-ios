//
//  NotificationService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import UserNotifications

// MARK: - Notification Service
@MainActor
class NotificationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var notificationError: String?
    
    // MARK: - Private Properties
    private let authService: AuthService
    private let apiService: APIService
    
    // MARK: - Initialization
    init(authService: AuthService) {
        self.authService = authService
        self.apiService = APIService(authService: authService)
        
        // Check initial notification status
        Task {
            await checkNotificationStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check current notification permission status
    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        // Also fetch server-side registration status when authenticated
        var serverRegistered: Bool = false
        if let _ = try? KeychainManager.retrieveJWTToken() {
            do {
                let status = try await apiService.getNotificationStatus()
                serverRegistered = status.registered
            } catch {
                // ignore; rely on local state if server fails
            }
        }
        
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized:
                // Reflect server registration if available
                self.isRegistered = serverRegistered || self.isRegistered
                if !self.isRegistered && self.deviceToken == nil {
                    Task { await self.registerForRemoteNotifications() }
                }
            case .denied:
                self.notificationError = "Notifications are disabled. Enable them in Settings."
                self.isRegistered = false
            case .notDetermined:
                self.notificationError = nil
                self.isRegistered = false
            case .provisional, .ephemeral:
                self.isRegistered = false
            @unknown default:
                self.isRegistered = false
            }
        }
    }
    
    /// Request notification permissions and register device token
    func requestNotificationPermissions() async {
        notificationError = nil
        
        do {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
                
                if granted {
                    await registerForRemoteNotifications()
                } else {
                    await MainActor.run {
                        notificationError = "Notification permissions denied"
                    }
                }
                
            case .denied:
                await MainActor.run {
                    notificationError = "Notifications are disabled. Please enable them in Settings."
                }
                // Open Settings app
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(settingsUrl)
                }
                
            case .authorized:
                await registerForRemoteNotifications()
                
            case .provisional, .ephemeral:
                await MainActor.run {
                    notificationError = "Limited notification permissions. Please enable full permissions in Settings."
                }
                
            @unknown default:
                await MainActor.run {
                    notificationError = "Unknown notification permission status"
                }
            }
        } catch {
            await MainActor.run {
                notificationError = "Failed to request permissions: \(error.localizedDescription)"
            }
        }
    }
    
    /// Register the device token with the API
    func registerDeviceToken(_ token: String) async {
        deviceToken = token
        guard authService.isAuthenticated else {
            notificationError = "Not authenticated. Cannot register device token."
            return
        }
        
        do {
            let success = try await apiService.registerDeviceToken(token)
            if success {
                isRegistered = true
                notificationError = nil
            } else {
                notificationError = "Failed to register device token"
            }
        } catch APIError.authenticationExpired {
            notificationError = "Authentication expired. Please sign in again."
        } catch {
            notificationError = "Registration failed: \(error.localizedDescription)"
        }
    }
    
    /// Unregister the current device token
    func unregisterDeviceToken() async {
        guard let token = deviceToken else { return }
        
        do {
            let success = try await apiService.removeDeviceToken(token)
            if success {
                isRegistered = false
                deviceToken = nil
                notificationError = nil
            } else {
                notificationError = "Failed to unregister device token"
            }
        } catch {
            notificationError = "Unregistration failed: \(error.localizedDescription)"
        }
    }
    
    /// Get all registered device tokens for the user
    func getRegisteredTokens() async -> [NotificationDetails] {
        do {
            return try await apiService.getDeviceTokens()
        } catch {
            notificationError = "Failed to fetch tokens: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Send a test notification
    func sendTestNotification() async {
        guard authService.isAuthenticated else {
            notificationError = "Not authenticated. Cannot send test notification."
            return
        }
        
        do {
            let success = try await apiService.sendTestNotification()
            if success {
                notificationError = nil
            } else {
                notificationError = "Failed to send test notification"
            }
        } catch {
            notificationError = "Test notification failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// MARK: - App Delegate Helper
extension NotificationService {
    
    /// Handle successful APNs registration
    func handleSuccessfulRegistration(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs registration successful. Device token: \(String(tokenString.prefix(16)))...")
        
        Task {
            await registerDeviceToken(tokenString)
        }
    }
    
    /// Handle failed APNs registration
    func handleFailedRegistration(error: Error) {
        Task {
            await MainActor.run {
                notificationError = "APNs registration failed: \(error.localizedDescription)"
            }
        }
    }
}