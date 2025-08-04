//
//  ContentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3

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
    let deletedAt: String?
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

// MARK: - Generic Comments Service
class CommentsService: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    
    private var currentPagination: Pagination?
    private var endCursor: String?
    private let serviceType: ServiceType
    private let parentCommentId: String?
    
    enum ServiceType {
        case mainComments
        case replies(parentId: String)
        case userComments(address: String)
    }
    
    init(serviceType: ServiceType = .mainComments) {
        self.serviceType = serviceType
        switch serviceType {
        case .mainComments:
            self.parentCommentId = nil
        case .replies(let parentId):
            self.parentCommentId = parentId
        case .userComments:
            self.parentCommentId = nil
        }
    }
    
    // Async version for SwiftUI's refreshable
    @MainActor
    func refreshComments() async {
        isRefreshing = true
        endCursor = nil
        currentPagination = nil
        errorMessage = nil
        
        let urlString = buildURL()
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isRefreshing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let commentsResponse = try JSONDecoder().decode(CommentsResponse.self, from: data)
            
            // Filter out deleted comments
            let filteredComments = commentsResponse.results.filter { $0.deletedAt == nil }
            self.comments = filteredComments
            
            self.currentPagination = commentsResponse.pagination
            self.endCursor = commentsResponse.pagination.hasNext ? commentsResponse.pagination.endCursor : nil
            
        } catch {
            self.errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
    
    func fetchComments(refresh: Bool = false) {
        if refresh {
            isRefreshing = true
            endCursor = nil
            currentPagination = nil
        }
        
        isLoading = !refresh && comments.isEmpty
        errorMessage = nil
        
        let urlString = buildURL()
        
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
                self?.isRefreshing = false
                
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
                    
                    // Filter out deleted comments
                    let filteredResults = commentsResponse.results.filter { $0.deletedAt == nil }
                    
                    if self?.isRefreshing == true || self?.comments.isEmpty == true {
                        self?.comments = filteredResults
                    } else {
                        // Append new comments, avoiding duplicates and deleted comments
                        let newComments = filteredResults.filter { newComment in
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
    
    private func buildURL() -> String {
        let url: String
        switch serviceType {
        case .mainComments:
            let baseURL = "https://api.ethcomments.xyz/api/comments?chainId=8453&moderationStatus=approved&moderationStatus=pending&limit=20&sort=desc&mode=nested"
            url = endCursor != nil ? "\(baseURL)&cursor=\(endCursor!)" : baseURL
            
        case .replies(let parentId):
            let baseURL = "https://api.ethcomments.xyz/api/comments/\(parentId)/replies?chainId=8453&limit=20"
            url = endCursor != nil ? "\(baseURL)&cursor=\(endCursor!)" : baseURL
            
        case .userComments(let address):
            let baseURL = "https://api.ethcomments.xyz/api/comments?chainId=8453&moderationStatus=approved&moderationStatus=pending&limit=20&sort=desc&mode=nested&author=\(address)"
            url = endCursor != nil ? "\(baseURL)&cursor=\(endCursor!)" : baseURL
        }
        return url
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
    @StateObject private var identityService = IdentityService()
    @State private var showingComposeModal = false
    @State private var showingSettingsModal = false
    @State private var currentUserAddress: String?
    @Environment(\.colorScheme) private var colorScheme
    
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
                                onCommentDeleted: {
                                    // Refresh the comments list after deletion
                                    commentsService.fetchComments(refresh: true)
                                }
                            )
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
                        await commentsService.refreshComments()
                    }
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.large)
            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .onAppear {
            if commentsService.comments.isEmpty {
                commentsService.fetchComments(refresh: true)
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


#Preview {
    ContentView()
}
