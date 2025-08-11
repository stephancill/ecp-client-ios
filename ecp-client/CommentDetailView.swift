//
//  CommentDetailView.swift
//  ecp-client
//
//  Created by Assistant on 2025/08/09.
//

import SwiftUI

struct CommentDetailView: View {
    let commentId: String
    let focusReplyId: String?
    let parentId: String?

    @State private var parentComment: Comment?
    @State private var mainComment: Comment?
    @State private var replies: [Comment] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Parent (skeleton or loaded)
            if let _ = parentId {
                Section(header: Text("In reply to").font(.caption).foregroundColor(.secondary)) {
                    if isLoading {
                        CommentSkeletonView()
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if let parent = parentComment {
                        CommentsList(
                            comments: [parent],
                            currentUserAddress: nil,
                            channelsService: nil
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }

            // Main comment (skeleton or loaded)
            Section {
                if isLoading {
                    CommentSkeletonView()
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if let main = mainComment {
                    CommentsList(
                        comments: [main],
                        currentUserAddress: nil,
                        channelsService: nil
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            // Replies (skeletons while loading or loaded replies)
            Section(header: Text("Replies").opacity((!replies.isEmpty || isLoading) ? 1 : 0)) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        CommentSkeletonView()
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    CommentsList(
                        comments: replies,
                        currentUserAddress: nil,
                        channelsService: nil
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Comment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await loadThread() } }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func loadThread() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1) Load main comment details
            let main = try await fetchCommentDetails(id: commentId)
            await MainActor.run { self.mainComment = main }

            // 2) If parentId provided (from deep link payload), fetch it
            if let pId = parentId, let p = try? await fetchCommentDetails(id: pId) {
                await MainActor.run { self.parentComment = p }
            }

            // 3) Load replies
            let repliesResponse = try await fetchReplies(id: main.id)
            await MainActor.run {
                self.replies = repliesResponse.results
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func fetchCommentDetails(id: String) async throws -> Comment {
        let base = "https://api.ethcomments.xyz/api/comments/\(id)?chainId=8453"
        guard let url = URL(string: base) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Comment.self, from: data)
    }

    // Parent ID resolution is handled via deep link payload from notifications for now

    private func fetchReplies(id: String) async throws -> Replies {
        let base = "https://api.ethcomments.xyz/api/comments/\(id)/replies?chainId=8453&limit=50&commentType=0"
        guard let url = URL(string: base) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Replies.self, from: data)
    }
}

#Preview {
    NavigationView { CommentDetailView(commentId: "example", focusReplyId: nil, parentId: nil) }
}

