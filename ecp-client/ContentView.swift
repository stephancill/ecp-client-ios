//
//  ContentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

// MARK: - Data Models
struct CommentsResponse: Codable {
    let results: [Comment]
    let pagination: Pagination
    let extra: Extra
}

struct Comment: Codable, Identifiable {
    let id: String
    let author: Author
    let content: String
    let createdAt: String
    let app: String
    let chainId: Int
    let references: [Reference]
    let reactionCounts: [String: Int]
    let replies: Replies?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = formatter.date(from: createdAt) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.dateTimeStyle = .named  
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return createdAt
    }
}

struct Author: Codable {
    let address: String
    let ens: ENS?
    let farcaster: Farcaster?
}

struct ENS: Codable {
    let name: String
    let avatarUrl: String?
}

struct Farcaster: Codable {
    let fid: Int
    let pfpUrl: String?
    let displayName: String
    let username: String
}

struct Reference: Codable {
    let type: String
    let url: String?
    let title: String?
    let symbol: String?
    let name: String?
    // ERC20-specific fields
    let address: String?
    let decimals: Int?
    let chainId: Int?
    let logoURI: String?
    let chains: [Chain]?
    // Position information
    let position: Position?
    // Farcaster-specific fields
    let fid: Int?
    let fname: String?
    let username: String?
    let displayName: String?
    let pfpUrl: String?
    // ENS-specific fields
    let avatarUrl: String?
}

struct Chain: Codable {
    let caip: String
    let chainId: Int
}

struct Position: Codable {
    let start: Int
    let end: Int
}

struct Replies: Codable {
    let results: [Comment]
    let pagination: Pagination
}

struct Pagination: Codable {
    let limit: Int
    let hasNext: Bool
    let hasPrevious: Bool
    let startCursor: String?
    let endCursor: String?
}

struct Extra: Codable {
    let moderationEnabled: Bool
    let moderationKnownReactions: [String]
}

// MARK: - Network Service
class CommentsService: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    
    private var currentPagination: Pagination?
    private var endCursor: String?
    
    func fetchComments(refresh: Bool = false) {
        if refresh {
            comments = []
            endCursor = nil
            currentPagination = nil
        }
        
        isLoading = refresh || comments.isEmpty
        errorMessage = nil
        
        let baseURL = "https://api.ethcomments.xyz/api/comments?chainId=8453&excludeByModerationLabels=spam%2Csexual&limit=20&sort=desc&mode=nested"
        let urlString = endCursor != nil ? "\(baseURL)&cursor=\(endCursor!)" : baseURL
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isLoadingMore = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let commentsResponse = try JSONDecoder().decode(CommentsResponse.self, from: data)
                    
                    if refresh || self?.comments.isEmpty == true {
                        self?.comments = commentsResponse.results
                    } else {
                        // Append new comments, avoiding duplicates
                        let newComments = commentsResponse.results.filter { newComment in
                            !(self?.comments.contains { $0.id == newComment.id } ?? false)
                        }
                        self?.comments.append(contentsOf: newComments)
                    }
                    
                    self?.currentPagination = commentsResponse.pagination
                    self?.endCursor = commentsResponse.pagination.hasNext ? commentsResponse.pagination.endCursor : nil
                } catch {
                    self?.errorMessage = "Failed to decode data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func loadMoreCommentsIfNeeded() {
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        
        isLoadingMore = true
        fetchComments(refresh: false)
    }
    
    var canLoadMore: Bool {
        return currentPagination?.hasNext == true && endCursor != nil
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var commentsService = CommentsService()
    @State private var showingComposeModal = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack {
                if commentsService.isLoading && commentsService.comments.isEmpty {
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
                } else if let errorMessage = commentsService.errorMessage {
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
                    VStack {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                            .font(.largeTitle)
                        Text("No comments yet")
                            .font(.headline)
                        Button("Load Comments") {
                            commentsService.fetchComments(refresh: true)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(commentsService.comments) { comment in
                            CommentRowView(comment: comment)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
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
                        commentsService.fetchComments(refresh: true)
                    }
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        commentsService.fetchComments(refresh: true)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
        }
        .overlay(
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
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
            ComposeCommentView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if commentsService.comments.isEmpty {
                commentsService.fetchComments(refresh: true)
            }
        }
    }
}










#Preview {
    ContentView()
}
