//
//  CommentRowView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3
import CachedAsyncImage

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment
    let currentUserAddress: String?
    let channelsService: ChannelsService?
    
    @State private var showingRepliesSheet = false
    @State private var showingUserDetailSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var channelInfo: Channel?
    @StateObject private var commentsService = CommentsContractService()
    @Environment(\.colorScheme) private var colorScheme
    
    // Callback for when comment is deleted
    var onCommentDeleted: (() -> Void)?
    
    init(comment: Comment, currentUserAddress: String? = nil, channelsService: ChannelsService? = nil, onCommentDeleted: (() -> Void)? = nil) {
        self.comment = comment
        self.currentUserAddress = currentUserAddress
        self.channelsService = channelsService
        self.onCommentDeleted = onCommentDeleted
    }
    
    // Constants for text truncation
    private let maxLines = 4
    
    // Computed property for consistent username display (centralized)
    private var displayUsername: String {
        return Utils.displayName(
            ensName: comment.author.ens?.name,
            farcasterUsername: comment.author.farcaster?.username,
            fallbackAddress: comment.author.address
        )
    }
    
    // Computed property for trimmed content
    private var trimmedContent: String {
        return comment.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Computed property to check if current user is the author
    private var isCurrentUserComment: Bool {
        guard let currentUserAddress = currentUserAddress else { return false }
        return comment.author.address.lowercased() == currentUserAddress.lowercased()
    }
    
    // Computed property for deduplicated references (excluding farcaster mentions, ENS, and images which are shown inline)
    private var deduplicatedReferences: [Reference] {
        var uniqueReferences: [Reference] = []
        var seenIdentifiers: Set<String> = []
        
        for reference in comment.references {
            // Skip farcaster, ENS, and image references as they're now shown inline
            if reference.type == "farcaster" || reference.type == "ens" || reference.type == "image" {
                continue
            }
            
            let identifier = getReferenceIdentifier(reference)
            if !seenIdentifiers.contains(identifier) {
                seenIdentifiers.insert(identifier)
                uniqueReferences.append(reference)
            }
        }
        
        return uniqueReferences
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author section
            HStack {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    showingUserDetailSheet = true
                }) {
                    HStack {
                        AvatarView(
                            address: comment.author.address,
                            size: 40,
                            ensAvatarUrl: comment.author.ens?.avatarUrl,
                            farcasterPfpUrl: comment.author.farcaster?.pfpUrl
                        )
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(displayUsername)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 6) {
                                Text(comment.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Channel chip (if available and not Home channel)
                                if let channelInfo = channelInfo, channelInfo.id != "0" {
                                    HStack(spacing: 4) {
                                        Image(systemName: "number")
                                            .font(.caption2)
                                        
                                        Text(channelInfo.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Kebab menu for current user's comments
                if isCurrentUserComment {
                    Menu {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(isDeleting)
                    } label: {
                        Image(systemName: isDeleting ? "ellipsis.circle" : "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDeleting ? .gray : .secondary)
                            .frame(width: 24, height: 24)
                    }
                    .sensoryFeedback(.impact, trigger: showingDeleteConfirmation)
                    .disabled(isDeleting)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                let parsedSegments = ContentParser.parseContent(trimmedContent, references: comment.references)
                
                ParsedContentView(
                    segments: parsedSegments,
                    maxLines: maxLines,
                    onUserTap: { username, displayName, address in
                        showingUserDetailSheet = true
                    }
                )
                .foregroundColor(isDeleting ? .gray : .primary)
                .opacity(isDeleting ? 0.6 : 1.0)
            }
            
            // References (links, tokens, etc.)
            if !deduplicatedReferences.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(deduplicatedReferences.indices, id: \.self) { index in
                            let reference = deduplicatedReferences[index]
                            ReferenceChip(reference: reference)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16) // Negative padding to extend to full screen width
            }
            
            // Reactions and replies
            HStack {
                if !comment.reactionCounts.isEmpty {
                    ForEach(comment.reactionCounts.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(spacing: 4) {
                            Image(systemName: reactionIcon(for: key))
                                .font(.caption)
                                .foregroundColor(reactionColor(for: key))
                            Text("\(value)")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Always show reply button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    showingRepliesSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption)
                        if let replies = comment.replies, !replies.results.isEmpty {
                            Text("\(replies.results.count)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Subtle divider
            Divider()
                .background(Color(.separator))
                .opacity(0.6)
                .padding(.horizontal, -16)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.clear)
        .disabled(isDeleting)
        .onAppear {
            // Load channel information if channelsService is available
            loadChannelInfo()
        }
        .sheet(isPresented: $showingRepliesSheet) {
            RepliesView(parentComment: comment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingUserDetailSheet) {
            UserDetailView(
                avatar: comment.author.ens?.avatarUrl ?? comment.author.farcaster?.pfpUrl,
                username: displayUsername,
                address: comment.author.address
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Comment", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteComment()
            }
            .disabled(isDeleting)
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Are you sure you want to delete this comment? This action cannot be undone.")
                
                if isDeleting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Deleting...")
                            .font(.caption)
                    }
                }
                
                if let deleteError = deleteError {
                    Text("Error: \(deleteError)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Delete Functionality
    private func deleteComment() {
        isDeleting = true
        deleteError = nil
        
        Task {
            do {
                // Retrieve stored data from keychain
                guard let identityAddress = try KeychainManager.retrieveIdentityAddress() else {
                    throw KeychainManager.KeychainError.itemNotFound
                }
                let privateKey = try KeychainManager.retrievePrivateKey()
                
                // Derive app address from private key
                let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
                let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
                let appAddress = ethereumPrivateKey.address.hex(eip55: true)
                
                // Set deadline (1 hour from now)
                let deadline = Date().timeIntervalSince1970 + 3600
                
                // Get the delete comment hash
                let deleteHash = try await commentsService.getDeleteCommentHash(
                    commentId: comment.id,
                    author: identityAddress,
                    app: appAddress,
                    deadline: deadline
                )
                
                // Convert delete hash to Data for signing
                let deleteHashData = Data(hex: deleteHash)
                
                // Sign the delete hash for app signature
                let signatureTuple = try ethereumPrivateKey.sign(hash: Array(deleteHashData))
                
                // Convert to canonical signature format (65-byte) for external utilities
                let appSignature = Utils.toCanonicalSignature(signatureTuple)
                
                // Use 32-byte zero signature for author signature (similar to post comment)
                let authorSignature = Data(count: 32)
                
                // Delete the comment
                let txHash = try await commentsService.deleteComment(
                    commentId: comment.id,
                    appAddress: appAddress,
                    deadline: deadline,
                    authorSignature: authorSignature,
                    appSignature: appSignature,
                    privateKey: privateKey
                )
                
                await MainActor.run {
                    showingDeleteConfirmation = false
                    // Notify parent to refresh the comments list
                    onCommentDeleted?()
                }
                
                print("✅ Comment deleted successfully. Transaction hash: \(txHash)")
                
            } catch KeychainManager.KeychainError.itemNotFound {
                await MainActor.run {
                    deleteError = "Please configure your identity and app settings first"
                    isDeleting = false
                }
            } catch {
                print("❌ Failed to delete comment: \(error)")
                await MainActor.run {
                    deleteError = "Failed to delete comment: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        }
    }
    
    
    
    // Helper function to create unique identifiers for references
    private func getReferenceIdentifier(_ reference: Reference) -> String {
        switch reference.type {
        case "erc20":
            // For ERC20 tokens, use address + chainId to identify uniqueness
            let address = reference.address?.lowercased() ?? ""
            let chainId = reference.chainId ?? 0
            return "erc20_\(address)_\(chainId)"
            
        case "webpage":
            // For webpages, use the URL
            return "webpage_\(reference.url ?? "")"
            
        case "ens":
            // For ENS, use the name
            return "ens_\(reference.name ?? "")"
            
        case "farcaster":
            // For Farcaster, use username or fid
            if let username = reference.username {
                return "farcaster_username_\(username)"
            } else if let fid = reference.fid {
                return "farcaster_fid_\(fid)"
            } else {
                // Fallback for farcaster references without username or fid
                let displayName = reference.displayName ?? ""
                return "farcaster_display_\(displayName)"
            }
            
        case "image":
            // For images, use the URL
            return "image_\(reference.url ?? "")"
            
        default:
            // For other types, create a general identifier
            let name = reference.name ?? reference.title ?? reference.symbol ?? ""
            return "\(reference.type)_\(name)"
        }
    }
    
    private func truncateAddress(_ address: String) -> String {
        return Utils.truncateAddress(address)
    }
    
    // MARK: - Channel Loading
    private func loadChannelInfo() {
        // Skip loading for Home channel (id: "0")
        guard comment.channelId != "0", let channelsService = channelsService else {
            return
        }
        
        // Check cache first
        if let cachedChannel = channelsService.getCachedChannel(id: comment.channelId) {
            channelInfo = cachedChannel
            return
        }
        
        // Fetch from API
        channelsService.fetchChannel(id: comment.channelId) { channel in
            DispatchQueue.main.async {
                channelInfo = channel
            }
        }
    }
    
    // MARK: - Reaction Helpers
    private func reactionIcon(for key: String) -> String {
        switch key.lowercased() {
        case "like":
            return "heart"
        case "repost":
            return "arrow.2.squarepath"
        case "upvote":
            return "arrow.up"
        case "downvote":
            return "arrow.down"
        default:
            return "hand.raised"
        }
    }
    
    private func reactionColor(for key: String) -> Color {
        switch key.lowercased() {
        case "like":
            return .red
        default:
            return .gray
        }
    }
} 