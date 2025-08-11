//
//  UserDetailView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import UIKit
import CachedAsyncImage

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - User Detail View
struct UserDetailView: View {
    let avatar: String?
    let username: String
    let address: String
    
    @StateObject private var commentsService: CommentsService
    @StateObject private var channelsService = ChannelsService()
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollOffset: CGFloat = 0
    @State private var showHeaderAvatar: Bool = false
    @State private var currentUserAddress: String?
    @EnvironmentObject private var authService: AuthService
    @State private var isSubscribedToPosts: Bool = false
    @State private var isTogglingSubscription: Bool = false
    
    init(avatar: String?, username: String, address: String) {
        self.avatar = avatar
        self.username = username
        self.address = address
        self._commentsService = StateObject(wrappedValue: CommentsService(serviceType: .userComments(address: address)))
    }
    
    // MARK: - Computed Properties
    private var avatarView: some View {
        AvatarView(
            address: address,
            size: 80,
            ensAvatarUrl: avatar,
            farcasterPfpUrl: avatar
        )
        .overlay(
            Circle()
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
    
    private var headerAvatarView: some View {
        AvatarView(
            address: address,
            size: 32,
            ensAvatarUrl: avatar,
            farcasterPfpUrl: avatar
        )
    }
    
        var body: some View {
        NavigationView {
            mainScrollView
        }
        .onAppear {
            // Fetch comments when view appears
            commentsService.fetchComments(refresh: true)
            // Load channels for channel display
            if channelsService.channels.isEmpty {
                channelsService.fetchChannels(refresh: true)
            }
            // Load current user's identity address
            loadCurrentUserAddress()
            Task { await refreshSubscriptionStatus() }
        }
    }
    
    // MARK: - Main Content Views
    
    private var mainScrollView: some View {
        ScrollView {
            scrollTracker
            mainContent
        }
        .coordinateSpace(name: "scroll")
        .refreshable {
            commentsService.fetchComments(refresh: true)
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: handleScrollOffset)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
    }
    
    private var scrollTracker: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, 
                          value: geometry.frame(in: .named("scroll")).minY)
        }
        .frame(height: 0)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            avatarSection
            commentsSection
        }
    }
    
    private var avatarSection: some View {
        VStack {
            avatarView
            
            Text(username)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(truncateAddress(address))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .opacity(showHeaderAvatar ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: showHeaderAvatar)
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            commentsSectionHeader
            commentsSectionContent
        }
    }
    
    private var commentsSectionHeader: some View {
        HStack {
            Text("Recent Comments")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var commentsSectionContent: some View {
        if commentsService.comments.isEmpty && commentsService.errorMessage == nil {
            loadingSkeletonView
        } else if let errorMessage = commentsService.errorMessage {
            errorView(message: errorMessage)
        } else if commentsService.comments.isEmpty {
            emptyCommentsView
        } else {
            commentsListView
        }
    }
    
    private var loadingSkeletonView: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                CommentSkeletonView()
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
            Button("Retry") {
                commentsService.fetchComments(refresh: true)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyCommentsView: some View {
        VStack {
            Image(systemName: "message")
                .foregroundColor(.gray)
                .font(.title2)
            Text("No comments yet")
                .font(.headline)
            Text("This user hasn't made any comments yet.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var commentsListView: some View {
        LazyVStack(spacing: 0) {
            CommentsList(
                comments: commentsService.comments,
                currentUserAddress: currentUserAddress,
                channelsService: channelsService,
                onCommentDeleted: {
                    commentsService.fetchComments(refresh: true)
                },
                onAppearLast: {
                    commentsService.loadMoreCommentsIfNeeded()
                }
            )
            loadMoreIndicator
        }
    }
    
    @ViewBuilder
    private var loadMoreIndicator: some View {
        if commentsService.isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 8) {
                if showHeaderAvatar {
                    headerAvatarView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(username)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(truncateAddress(address))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .opacity(showHeaderAvatar ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showHeaderAvatar)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { Task { await toggleSubscription() } }) {
                if isTogglingSubscription {
                    ProgressView()
                } else {
                    Image(systemName: isSubscribedToPosts ? "bell.fill" : "bell")
                }
            }
            .disabled(isTogglingSubscription)
            .accessibilityLabel(isSubscribedToPosts ? "Disable post notifications" : "Enable post notifications")
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleScrollOffset(_ value: CGFloat) {
        DispatchQueue.main.async {
            let offset = value
            scrollOffset = offset
            
            // Show header avatar when scrolled past avatar section (approximately 140 points)
            withAnimation(.easeInOut(duration: 0.2)) {
                showHeaderAvatar = offset < -140
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadCurrentUserAddress() {
        do {
            currentUserAddress = try KeychainManager.retrieveIdentityAddress()
        } catch {
            // Silently handle error - user might not have set up identity yet
            currentUserAddress = nil
        }
    }

    private func refreshSubscriptionStatus() async {
        guard authService.isAuthenticated else { return }
        let api = APIService(authService: authService)
        do {
            let subscribed = try await api.isSubscribedToPosts(of: address)
            await MainActor.run { self.isSubscribedToPosts = subscribed }
        } catch {
            // ignore
        }
    }

    private func toggleSubscription() async {
        guard authService.isAuthenticated else { return }
        isTogglingSubscription = true
        let api = APIService(authService: authService)
        do {
            if isSubscribedToPosts {
                _ = try await api.unsubscribeFromPosts(of: address)
                isSubscribedToPosts = false
            } else {
                _ = try await api.subscribeToPosts(of: address)
                isSubscribedToPosts = true
            }
        } catch {
            // TODO: surface an error banner if desired
        }
        isTogglingSubscription = false
    }
}

// MARK: - Helper Functions
private func truncateAddress(_ address: String) -> String {
    guard address.count > 10 else { return address }
    let start = String(address.prefix(6))
    let end = String(address.suffix(4))
    return "\(start)...\(end)"
}

#Preview {
    UserDetailView(
        avatar: "https://imagedelivery.net/BXluQx4ige9GuW0Ia56BHw/e738382d-7e8c-41f1-9d6d-dedf55df2f00/original",
        username: "df",
        address: "0xdaa83039aca9a33b2e54bb2acc9f9c3a99357618"
    )
} 