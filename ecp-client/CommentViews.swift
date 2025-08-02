//
//  CommentViews.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: Comment
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Constants for text truncation
    private let maxLines = 4
    private let maxHeight: CGFloat = 160 // Approximately 8 lines of text
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author section
            HStack {
                AsyncImage(url: URL(string: comment.author.farcaster?.pfpUrl ?? comment.author.ens?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    if let displayName = comment.author.farcaster?.displayName {
                        Text(displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else if let ensName = comment.author.ens?.name {
                        Text(ensName)
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Text(String(comment.author.address.prefix(8)) + "...")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(comment.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Content with max height and show more button
            VStack(alignment: .leading, spacing: 8) {
                Text(comment.content)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : maxLines)
                    .frame(maxHeight: isExpanded ? nil : maxHeight, alignment: .top)
                    .clipped()
                
                // Show more/less button
                if comment.content.count > 200 || comment.content.components(separatedBy: "\n").count > maxLines {
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
            if !comment.references.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(comment.references.indices, id: \.self) { index in
                            let reference = comment.references[index]
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
                
                if let replies = comment.replies, !replies.results.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption)
                        Text("\(replies.results.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
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
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.clear)
    }
}

// MARK: - Reference Chip View
struct ReferenceChip: View {
    let reference: Reference
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForReferenceType(reference.type))
                .font(.caption)
            
            if let title = reference.title {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            } else if let name = reference.name {
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Text(reference.type.capitalized)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
        .onTapGesture {
            if reference.type == "webpage", let urlString = reference.url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func iconForReferenceType(_ type: String) -> String {
        switch type {
        case "webpage":
            return "link"
        case "erc20":
            return "bitcoinsign.circle"
        case "ens":
            return "globe"
        case "farcaster":
            return "person.circle"
        default:
            return "tag"
        }
    }
}

// MARK: - Comment Skeleton View
struct CommentSkeletonView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author section skeleton
            HStack {
                // Avatar skeleton
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .shimmering(isAnimating: isAnimating)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 16)
                        .shimmering(isAnimating: isAnimating)
                    
                    // Date skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 12)
                        .shimmering(isAnimating: isAnimating)
                }
                
                Spacer()
            }
            
            // Content skeleton - multiple lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .shimmering(isAnimating: isAnimating)
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 16)
                        .shimmering(isAnimating: isAnimating)
                    Spacer()
                        .frame(width: 60)
                }
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 16)
                        .shimmering(isAnimating: isAnimating)
                    Spacer()
                        .frame(width: 120)
                }
            }
            
            // References skeleton
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 24)
                    .shimmering(isAnimating: isAnimating)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 24)
                    .shimmering(isAnimating: isAnimating)
                
                Spacer()
            }
            
            // Reactions skeleton
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 20)
                    .shimmering(isAnimating: isAnimating)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 12)
                    .shimmering(isAnimating: isAnimating)
            }
            
            // Subtle divider
            Divider()
                .background(Color(.separator))
                .opacity(0.6)
                .padding(.horizontal, -16)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.clear)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerModifier: ViewModifier {
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.6 : 1.0)
    }
}

extension View {
    func shimmering(isAnimating: Bool) -> some View {
        self.modifier(ShimmerModifier(isAnimating: isAnimating))
    }
} 