//
//  RepliesView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

// MARK: - Replies View
struct RepliesView: View {
    let parentComment: Comment
    @StateObject private var repliesService: CommentsService
    @StateObject private var channelsService = ChannelsService()
    @StateObject private var identityService = IdentityService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentUserAddress: String?
    @State private var showingComposeModal = false
    @State private var replyTarget: Comment?
    @State private var composePresentationDetents: Set<PresentationDetent> = [.medium, .large]
    
    init(parentComment: Comment) {
        self.parentComment = parentComment
        self._repliesService = StateObject(wrappedValue: CommentsService(serviceType: .replies(parentId: parentComment.id)))
        self._replyTarget = State(initialValue: parentComment)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if (repliesService.isLoading || repliesService.isRefreshing) && repliesService.comments.isEmpty {
                    // Show skeleton views during initial load
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
                } else if let errorMessage = repliesService.errorMessage {
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
                            repliesService.fetchComments(refresh: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if repliesService.comments.isEmpty {
                    VStack {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                        Text("No replies yet")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                } else {
                    List {
                        // Replies using the same styling as main comments
                        CommentsList(
                            comments: repliesService.comments,
                            currentUserAddress: currentUserAddress,
                            channelsService: channelsService,
                            onCommentDeleted: {
                                repliesService.fetchComments(refresh: true)
                            },
                            onAppearLast: {
                                repliesService.loadMoreCommentsIfNeeded()
                            },
                            onReplyTapped: { tapped in
                                replyTarget = tapped
                                showingComposeModal = true
                            }
                        )
                        
                        // Loading indicator at bottom
                        if repliesService.isLoadingMore {
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
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        repliesService.fetchComments(refresh: true)
                    }
                }
            }
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .overlay(
            // Floating Action Button for replying
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingComposeModal = true
                    }) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 18, weight: .semibold))
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
                parentComment: replyTarget ?? parentComment,
                onCommentPosted: {
                    // Refresh the replies when comment is posted
                    repliesService.fetchComments(refresh: true)
                },
                presentationDetents: $composePresentationDetents
            )
            .presentationDetents(composePresentationDetents)
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if repliesService.comments.isEmpty {
                repliesService.fetchComments(refresh: true)
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