//
//  UserDetailView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

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
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollOffset: CGFloat = 0
    @State private var showHeaderAvatar: Bool = false
    
    init(avatar: String?, username: String, address: String) {
        self.avatar = avatar
        self.username = username
        self.address = address
        self._commentsService = StateObject(wrappedValue: CommentsService(serviceType: .userComments(address: address)))
    }
    
    // MARK: - Computed Properties
    private var avatarView: some View {
        Group {
            if let avatarUrl = avatar, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    case .failure(_):
                        // Image failed to load, show blockies
                        BlockiesAvatarView(address: address, size: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    @unknown default:
                        BlockiesAvatarView(address: address, size: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    }
                }
            } else {
                BlockiesAvatarView(address: address, size: 80)
                    .overlay(
                        Circle()
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
        }
    }
    
    private var headerAvatarView: some View {
        Group {
            if let avatarUrl = avatar, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    case .failure(_):
                        BlockiesAvatarView(address: address, size: 32)
                    case .empty:
                        BlockiesAvatarView(address: address, size: 32)
                    @unknown default:
                        BlockiesAvatarView(address: address, size: 32)
                    }
                }
            } else {
                BlockiesAvatarView(address: address, size: 32)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                // Hidden geometry reader for scroll tracking
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, 
                                  value: geometry.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)
                
                VStack(spacing: 0) {
                    // Avatar section
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
                
                    // Comments section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Comments")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        if commentsService.comments.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(0..<5, id: \.self) { _ in
                                    CommentSkeletonView()
                                }
                            }

                        } else if let errorMessage = commentsService.errorMessage {
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                Text("Error")
                                    .font(.headline)
                                Text(errorMessage)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                Button("Retry") {
                                    commentsService.fetchComments(refresh: true)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        } else if commentsService.comments.isEmpty {
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

                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(commentsService.comments) { comment in
                                    CommentRowView(comment: comment, showRepliesButton: false)
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
                                } else if !commentsService.canLoadMore && !commentsService.comments.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("No more comments")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }

                        }
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .refreshable {
                commentsService.fetchComments(refresh: true)
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                DispatchQueue.main.async {
                    let offset = value
                    scrollOffset = offset
                    
                    // Show header avatar when scrolled past avatar section (approximately 140 points)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHeaderAvatar = offset < -140
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                

            }
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
        }
        .onAppear {
            // Fetch comments when view appears
            commentsService.fetchComments(refresh: true)
        }
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
        avatar: "https://example.com/avatar.jpg",
        username: "example.eth",
        address: "0x1234567890123456789012345678901234567890"
    )
} 