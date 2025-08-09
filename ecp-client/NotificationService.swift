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
    @Published var events: [NotificationEvent] = []
    @Published var isLoadingEvents: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var nextCursor: String? = nil
    @Published var hasUnread: Bool = false
    
    // MARK: - Private Properties
    private let authService: AuthService
    private let apiService: APIService
    private var unreadPollTask: Task<Void, Never>? = nil
    
    // MARK: - Initialization
    init(authService: AuthService) {
        self.authService = authService
        self.apiService = APIService(authService: authService)
        
        // Check initial notification status
        Task {
            await checkNotificationStatus()
        }

        // Start unread polling
        startUnreadPolling()
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

    /// Fetch notification history
    func fetchEvents(limit: Int = 50) async {
        guard authService.isAuthenticated else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let page = try await apiService.getNotificationEvents(limit: limit)
            await MainActor.run {
                self.events = page.events
                self.nextCursor = page.nextCursor
                self.updateUnreadFromLatest()
            }
        } catch {
            await MainActor.run {
                self.notificationError = "Failed to load notifications: \(error.localizedDescription)"
            }
        }
    }

    func loadMoreIfNeeded(currentItem item: NotificationEvent?) async {
        guard let item = item else { return }
        guard let last = events.last, last.id == item.id else { return }
        guard !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await apiService.getNotificationEvents(limit: 50, cursor: cursor)
            await MainActor.run {
                self.events.append(contentsOf: page.events)
                self.nextCursor = page.nextCursor
            }
        } catch {
            await MainActor.run {
                self.notificationError = "Failed to load more: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Unread Tracking
    private func startUnreadPolling() {
        unreadPollTask?.cancel()
        unreadPollTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                do {
                    // Lightweight: ask for just 1 event
                    let page = try await self.apiService.getNotificationEvents(limit: 1)
                    await MainActor.run {
                        if let latest = page.events.first {
                            self.updateUnreadFrom(latestCreatedAt: latest.createdAt)
                        } else {
                            self.hasUnread = false
                        }
                    }
                } catch {
                    // ignore transient errors
                }
                // Poll every 30 seconds
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            }
        }
    }

    private func updateUnreadFromLatest() {
        if let latest = events.first?.createdAt {
            updateUnreadFrom(latestCreatedAt: latest)
        } else {
            hasUnread = false
        }
    }

    private func updateUnreadFrom(latestCreatedAt: String) {
        guard let latestDate = parseISODate(latestCreatedAt) else { hasUnread = false; return }
        let lastRead = lastReadDate()
        hasUnread = lastRead == nil || latestDate > lastRead!
    }

    func markAllAsRead() {
        saveLastReadDate(Date())
        updateUnreadFromLatest()
    }

    private func userDefaultsKey() -> String {
        let userId = authService.getAppAddress() ?? "anonymous"
        return "notifications.lastRead.\(userId.lowercased())"
    }

    private func lastReadDate() -> Date? {
        let key = userDefaultsKey()
        if let iso = UserDefaults.standard.string(forKey: key) {
            return parseISODate(iso)
        }
        return nil
    }

    private func saveLastReadDate(_ date: Date) {
        let key = userDefaultsKey()
        let iso = iso8601String(from: date)
        UserDefaults.standard.set(iso, forKey: key)
    }

    private func parseISODate(_ iso: String) -> Date? {
        let isoFs = ISO8601DateFormatter()
        isoFs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFs.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = isoFs.date(from: iso) { return d }
        let isoNoFs = ISO8601DateFormatter()
        isoNoFs.formatOptions = [.withInternetDateTime]
        isoNoFs.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = isoNoFs.date(from: iso) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let d = df.date(from: iso) { return d }
        return nil
    }

    private func iso8601String(from date: Date) -> String {
        let isoFs = ISO8601DateFormatter()
        isoFs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFs.timeZone = TimeZone(secondsFromGMT: 0)
        return isoFs.string(from: date)
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