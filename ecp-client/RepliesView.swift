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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(parentComment: Comment) {
        self.parentComment = parentComment
        self._repliesService = StateObject(wrappedValue: CommentsService(serviceType: .replies(parentId: parentComment.id)))
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
                        Text("Be the first to reply!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // Replies using the same styling as main comments
                        ForEach(repliesService.comments) { reply in
                            CommentRowView(comment: reply, showRepliesButton: false)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    // Load more when approaching the end
                                    if reply.id == repliesService.comments.last?.id {
                                        repliesService.loadMoreCommentsIfNeeded()
                                    }
                                }
                        }
                        
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
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
        }
        .onAppear {
            if repliesService.comments.isEmpty {
                repliesService.fetchComments(refresh: true)
            }
        }
    }
} 