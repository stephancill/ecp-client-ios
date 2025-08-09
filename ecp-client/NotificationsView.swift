//
//  NotificationsView.swift
//  ecp-client
//
//  Created by Assistant on 2025/08/09.
//

import SwiftUI
import UIKit

struct NotificationsView: View {
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var deepLinkService: DeepLinkService
    @Environment(\.dismiss) private var dismiss
    // Route is handed off to ContentView via deepLinkService to avoid nested sheets
    @Environment(\.colorScheme) private var colorScheme
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        List {
            if notificationService.isLoadingEvents && notificationService.events.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                                .padding(.trailing, 40)
                        }
                    }
                    .redacted(reason: .placeholder)
                }
            } else if notificationService.events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No notifications yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                // Build display list with grouped reactions while preserving order
                let displayEvents: [NotificationEvent] = {
                    var result: [NotificationEvent] = []
                    var seen = Set<String>()
                    for e in notificationService.events {
                        if (e.type ?? "") == "reaction" {
                            let key = e.groupKey ?? "reaction:\(e.targetCommentId ?? ""):\(e.reactionType ?? "")"
                            if seen.contains(key) { continue }
                            seen.insert(key)
                        }
                        result.append(e)
                    }
                    return result
                }()

                ForEach(displayEvents, id: \.id) { event in
                    HStack(alignment: .top, spacing: 12) {
                        // Notification type icon
                        NotificationIconView(type: event.type)
                            .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    // User profile image above title
                                    if let actorProfile = event.actorProfile {
                                        BlockiesAvatarView(
                                            address: actorProfile.address,
                                            size: 24
                                        )
                                    }
                                    
                                    Text(event.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                Text(formatDate(event.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if event.type == "reaction" {
                                let count = notificationService.events.filter {
                                    ($0.type ?? "") == "reaction" &&
                                    $0.targetCommentId == event.targetCommentId &&
                                    $0.reactionType == event.reactionType
                                }.count
                                if count > 1 {
                                    Text("\(count) \(event.reactionType ?? "reaction")s on your comment")
                                        .font(.body)
                                } else {
                                    Text(event.body)
                                        .font(.body)
                                }
                            } else {
                                Text(event.body)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .onAppear {
                        Task { await notificationService.loadMoreIfNeeded(currentItem: event) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap(event) }
                }
                if notificationService.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refresh()
        }
        .onAppear {
            if notificationService.events.isEmpty {
                Task { await notificationService.fetchEvents() }
            }
            // Mark all as read when opening the notifications view
            notificationService.markAllAsRead()
        }
        // Intentionally no local sheet presentation here; nested sheets can dismiss each other
    }
    
    private func refresh() async {
        await notificationService.fetchEvents()
    }
    
    private func formatDate(_ iso: String) -> String {
        guard let date = parseISODate(iso) else { return iso }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // Custom short format
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 2592000 { // 30 days
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else {
            let months = Int(timeInterval / 2592000)
            return "\(months)mo"
        }
    }

    private func parseISODate(_ iso: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        let isoFs = ISO8601DateFormatter()
        isoFs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFs.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = isoFs.date(from: iso) { return d }

        // Fallback: ISO8601 without fractional seconds
        let isoNoFs = ISO8601DateFormatter()
        isoNoFs.formatOptions = [.withInternetDateTime]
        isoNoFs.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = isoNoFs.date(from: iso) { return d }

        // Fallback: explicit formatter with milliseconds
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let d = df.date(from: iso) { return d }

        return nil
    }
    
    private func displayName(from profile: AuthorProfile) -> String {
        return Utils.displayName(
            ensName: profile.ens?.name,
            farcasterUsername: profile.farcaster?.username,
            fallbackAddress: profile.address
        )
    }

    private func handleTap(_ event: NotificationEvent) {
        guard let data = event.data else { return }
        let type = (event.type ?? data["type"]?.stringValue)?.lowercased()
        let commentId = event.subjectCommentId ?? data["commentId"]?.stringValue
        let parentId = event.parentCommentId ?? data["parentId"]?.stringValue
        // Hand off to root presenter and dismiss this sheet to avoid nested-sheet conflicts
        switch type {
        case "reply":
            if let id = commentId {
                deepLinkService.pendingRoute = .comment(id: id, focusReplyId: id, parentId: parentId)
                dismiss()
            }
        case "like", "reaction":
            if let id = parentId ?? commentId {
                deepLinkService.pendingRoute = .comment(id: id, focusReplyId: nil, parentId: nil)
                dismiss()
            }
        default:
            if let id = commentId {
                deepLinkService.pendingRoute = .comment(id: id, focusReplyId: nil, parentId: parentId)
                dismiss()
            }
        }
    }
}

// MARK: - AvatarView
struct AvatarView: View {
    let profile: AuthorProfile?
    var body: some View {
        Group {
            if let url = firstValidURL(from: profile) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): Circle().fill(Color.gray.opacity(0.3))
                    case .empty: Circle().fill(Color.gray.opacity(0.3))
                    @unknown default: Circle().fill(Color.gray.opacity(0.3))
                    }
                }
            } else {
                Circle().fill(Color.gray.opacity(0.3))
            }
        }
    }

    private func firstValidURL(from profile: AuthorProfile?) -> URL? {
        guard let profile = profile else { return nil }
        let candidates = [profile.ens?.avatarUrl, profile.farcaster?.pfpUrl]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for raw in candidates {
            if let url = urlFrom(raw: raw) {
                return url
            }
        }
        return nil
    }

    private func urlFrom(raw: String) -> URL? {
        let urlStr = normalizeURLString(raw)
        if urlStr.lowercased().hasPrefix("data:image/") {
            return nil
        }
        return URL(string: urlStr)
    }

    private func normalizeURLString(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("ipfs://") {
            let path = String(trimmed.dropFirst("ipfs://".count))
            return "https://ipfs.io/ipfs/" + path.replacingOccurrences(of: "ipfs/", with: "")
        }
        if trimmed.lowercased().hasPrefix("ar://") {
            let id = String(trimmed.dropFirst("ar://".count))
            return "https://arweave.net/" + id
        }
        if trimmed.hasPrefix("//") { return "https:" + trimmed }
        return trimmed
    }
}

// MARK: - NotificationIconView
struct NotificationIconView: View {
    let type: String?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColorForType)
            
            Image(systemName: iconForType)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColorForType)
        }
    }
    
    private var iconForType: String {
        switch type?.lowercased() {
        case "reply":
            return "arrowshape.turn.up.left.fill"
        case "reaction":
            return "heart.fill"
        case "mention":
            return "at"
        case "follow":
            return "person.badge.plus.fill"
        case "system":
            return "gear.circle.fill"
        default:
            return "bell.fill"
        }
    }
    
    private var backgroundColorForType: Color {
        switch type?.lowercased() {
        case "reply":
            return .blue.opacity(0.15)
        case "reaction":
            return .pink.opacity(0.15)
        case "mention":
            return .orange.opacity(0.15)
        case "follow":
            return .green.opacity(0.15)
        case "system":
            return .gray.opacity(0.15)
        default:
            return .primary.opacity(0.1)
        }
    }
    
    private var iconColorForType: Color {
        switch type?.lowercased() {
        case "reply":
            return .blue
        case "reaction":
            return .pink
        case "mention":
            return .orange
        case "follow":
            return .green
        case "system":
            return .gray
        default:
            return .primary
        }
    }
}

#Preview {
    let authService = AuthService()
    let notificationService = NotificationService(authService: authService)
    return NavigationView { NotificationsView() }
        .environmentObject(notificationService)
        .environmentObject(authService)
}

