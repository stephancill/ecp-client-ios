//
//  CommentRowView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment
    let showRepliesButton: Bool
    @State private var isExpanded = false
    @State private var showingRepliesSheet = false
    @State private var showingUserDetailSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(comment: Comment, showRepliesButton: Bool = true) {
        self.comment = comment
        self.showRepliesButton = showRepliesButton
    }
    
    // Constants for text truncation
    private let maxLines = 4
    private let maxHeight: CGFloat = 160 // Approximately 8 lines of text
    
    // Computed property for consistent username display
    private var displayUsername: String {
        if let username = comment.author.farcaster?.username, !username.hasPrefix("!") {
            return username
        } else if let ensName = comment.author.ens?.name {
            return ensName
        } else {
            return truncateAddress(comment.author.address)
        }
    }
    
    // Computed property for trimmed content
    private var trimmedContent: String {
        return comment.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Computed property for deduplicated references (excluding farcaster mentions which are shown inline)
    private var deduplicatedReferences: [Reference] {
        var uniqueReferences: [Reference] = []
        var seenIdentifiers: Set<String> = []
        
        for reference in comment.references {
            // Skip farcaster and ENS references as they're now shown inline
            if reference.type == "farcaster" || reference.type == "ens" {
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
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                showingUserDetailSheet = true
            }) {
                HStack {
                    Group {
                        if let imageUrl = comment.author.farcaster?.pfpUrl ?? comment.author.ens?.avatarUrl,
                           !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                case .failure(_):
                                    // Image failed to load, show blockies
                                    BlockiesAvatarView(address: comment.author.address, size: 40)
                                case .empty:
                                    // Loading state - show a simple placeholder
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                @unknown default:
                                    BlockiesAvatarView(address: comment.author.address, size: 40)
                                }
                            }
                        } else {
                            // No image URL available, show blockies immediately
                            BlockiesAvatarView(address: comment.author.address, size: 40)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text(displayUsername)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(comment.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Content with max height and show more button
            VStack(alignment: .leading, spacing: 8) {
                let parsedSegments = ContentParser.parseContent(trimmedContent, references: comment.references)
                
                ParsedContentView(
                    segments: parsedSegments,
                    isExpanded: isExpanded,
                    maxLines: maxLines,
                    maxHeight: maxHeight,
                    onUserTap: { username, displayName, address in
                        showingUserDetailSheet = true
                    }
                )
                
                // Show more/less button - use trimmed content for length check
                if shouldShowMoreButton {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
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
                    .padding(.horizontal, 4)
                }
            }
            
            // Reactions and replies
            HStack {
                if !comment.reactionCounts.isEmpty {
                    ForEach(comment.reactionCounts.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(spacing: 4) {
                            Text(key == "like" ? "❤️" : key)
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
                
                if showRepliesButton, let replies = comment.replies, !replies.results.isEmpty {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showingRepliesSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.caption)
                            Text("\(replies.results.count)")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Subtle divider
            Divider()
                .background(Color(.separator))
                .opacity(0.6)
                .padding(.horizontal, -16)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
        .sheet(isPresented: $showingRepliesSheet) {
            RepliesView(parentComment: comment)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingUserDetailSheet) {
            UserDetailView(
                avatar: comment.author.farcaster?.pfpUrl ?? comment.author.ens?.avatarUrl,
                username: displayUsername,
                address: comment.author.address
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // Computed property to determine if we should show the "Show more" button
    private var shouldShowMoreButton: Bool {
        return trimmedContent.count > 200 || trimmedContent.components(separatedBy: "\n").count > maxLines
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
            
        default:
            // For other types, create a general identifier
            let name = reference.name ?? reference.title ?? reference.symbol ?? ""
            return "\(reference.type)_\(name)"
        }
    }
    
    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = String(address.prefix(6))  // 0x1234
        let suffix = String(address.suffix(4))  // abcd
        return "\(prefix)...\(suffix)"
    }
} 