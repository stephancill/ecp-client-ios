//
//  ContentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3

// MARK: - Views
struct ContentView: View {
    @StateObject private var commentsService = CommentsService()
    @StateObject private var channelsService = ChannelsService()
    @StateObject private var identityService = IdentityService()
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var notificationService: NotificationService
    @State private var showingComposeModal = false
    @State private var showingSettingsModal = false
    @State private var showingNotificationsModal = false
    @State private var currentUserAddress: String?
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var deepLinkService: DeepLinkService
    @State private var presentedDetailRoute: DeepLinkService.Route?
    
    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = commentsService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.largeTitle)
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            commentsService.fetchComments(refresh: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if commentsService.comments.isEmpty {
                    // Show skeleton views when no data exists
                    List {
                        ForEach(0..<8, id: \.self) { _ in
                            CommentSkeletonView()
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .disabled(true)
                } else {
                    List {
                        ForEach(commentsService.comments) { comment in
                            CommentRowView(
                                comment: comment, 
                                currentUserAddress: currentUserAddress,
                                channelsService: channelsService,
                                onCommentDeleted: {
                                    // Refresh the comments list after deletion
                                    commentsService.fetchComments(refresh: true)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onAppear {
                                // Load more when approaching the end
                                if comment.id == commentsService.comments.last?.id {
                                    commentsService.loadMoreCommentsIfNeeded()
                                }
                            }
                        }
                        
                        // Loading indicator at bottom
                        if commentsService.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else if !commentsService.canLoadMore && !commentsService.comments.isEmpty {
                            HStack {
                                Spacer()
                                Text("No more comments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await commentsService.refreshComments()
                    }
                }
            }
            .navigationTitle("Posts")
            .navigationBarTitleDisplayMode(.large)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingNotificationsModal = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                            if true {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                        .frame(width: 24, height: 24, alignment: .center)
                    }
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingSettingsModal = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
        .overlay(
            // Floating Action Button - always visible
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingComposeModal = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        )
        .sheet(isPresented: $showingComposeModal) {
            ComposeCommentView(
                identityService: identityService,
                parentComment: nil,
                onCommentPosted: {
                    // Refresh the feed when comment is posted
                    Task {
                        await commentsService.refreshComments()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettingsModal, onDismiss: {
            // Reload identity address when settings sheet closes
            loadCurrentUserAddress()
            // Re-check identity configuration
            Task {
                await identityService.checkIdentityConfiguration()
            }
        }) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotificationsModal) {
            NavigationView { NotificationsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if commentsService.comments.isEmpty {
                commentsService.fetchComments(refresh: true)
            }
            // Load channels for channel display
            if channelsService.channels.isEmpty {
                channelsService.fetchChannels(refresh: true)
            }
            // Load current user's identity address
            loadCurrentUserAddress()
            // Check identity configuration
            Task {
                await identityService.checkIdentityConfiguration()
            }
        }
        .sheet(item: $presentedDetailRoute) { route in
            switch route {
            case .comment(let id, let focus, let parentId):
                NavigationView { CommentDetailView(commentId: id, focusReplyId: focus, parentId: parentId) }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: deepLinkService.route) { _, newValue in
            guard let route = newValue else { return }
            presentedDetailRoute = route
            // Clear source after scheduling presentation, but don't trigger dismissal
            DispatchQueue.main.async {
                deepLinkService.route = nil
            }
        }
        .onChange(of: showingNotificationsModal) { _, newValue in
            // When notifications modal closes, promote pendingRoute to route to trigger presentation
            if newValue == false, let pending = deepLinkService.pendingRoute {
                DispatchQueue.main.async {
                    self.presentedDetailRoute = pending
                    deepLinkService.pendingRoute = nil
                }
            }
            // When the sheet opens, mark all as read
            if newValue == true {
                notificationService.markAllAsRead()
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
    

}


#Preview {
    let authService = AuthService()
    let notificationService = NotificationService(authService: authService)
    let deepLinkService = DeepLinkService()
    return ContentView()
        .environmentObject(authService)
        .environmentObject(notificationService)
        .environmentObject(deepLinkService)
}
