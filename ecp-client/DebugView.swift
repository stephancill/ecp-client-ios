//
//  DebugView.swift
//  ecp-client
//

import SwiftUI
import UIKit

struct DebugView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var notificationService: NotificationService
    private let baseURL: String = AppConfiguration.shared.baseURL

    var body: some View {
        List {
            // Authentication
            Section(
                header: Text("Authentication"),
                footer: Text("App authenticates on startup; you can also manually retry here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack {
                            if authService.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Authenticating...")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: authService.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(authService.isAuthenticated ? .green : .red)
                                    Text(authService.isAuthenticated ? "Authenticated" : "Not Authenticated")
                                        .foregroundColor(authService.isAuthenticated ? .green : .red)
                                }
                            }

                            Spacer()

                            Button(action: {
                                Task { await authService.authenticate() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                            }
                            .disabled(authService.isLoading)
                        }
                    }

                    if let error = authService.authError {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    if authService.isAuthenticated {
                        Divider()
                        Button(action: {
                            Task { await authService.signOut() }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .disabled(authService.isLoading)
                    }
                }
            }

            // JWT section separated to keep a single press handler in this section
            if authService.isAuthenticated, let jwt = authService.getAuthToken() {
                Section(
                    header: Text("JWT Token"),
                    footer: Text("Tap the row to copy the token to clipboard.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
                    Button(action: { UIPasteboard.general.string = jwt }) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(jwt)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .accessibilityLabel("Copy JWT Token")
                }
            }

            Section(
                header: Text("Configuration"),
                footer: Text("Values are resolved at app launch. In CI, set `API_BASE_URL` to override.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Base URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(baseURL)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            // Push Notifications Debug
            Section(
                header: Text("Push Notifications"),
                footer: Text("Use these tools to verify and troubleshoot push notifications on device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: notificationService.isRegistered ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationService.isRegistered ? .green : .secondary)
                        Text(notificationService.isRegistered ? "Enabled" : "Disabled")
                            .foregroundColor(notificationService.isRegistered ? .green : .secondary)
                        Spacer()
                    }

                    if let token = notificationService.deviceToken {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Device Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(token)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }

                    if let error = notificationService.notificationError {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Error")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            if notificationService.isRegistered {
                Section(header: Text("Notification Actions")) {
                    Button(action: { Task { await notificationService.sendTestNotification() } }) {
                        HStack {
                            Image(systemName: "paperplane")
                                .foregroundColor(.green)
                            Text("Send Test Notification")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }

                Section(header: Text("Notification Management")) {
                    Button(action: { Task { await notificationService.unregisterDeviceToken() } }) {
                        HStack {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.red)
                            Text("Disable Notifications")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
}

#Preview("Debug") {
    NavigationView { DebugView() }
}

