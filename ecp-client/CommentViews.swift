//
//  CommentViews.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

// MARK: - Blockies Avatar View
struct BlockiesAvatarView: View {
    let address: String
    let size: CGFloat
    
    var body: some View {
        if let blockiesImage = generateBlockiesImage(from: address, size: Int(size)) {
            Image(uiImage: blockiesImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Fallback to the original placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                )
                .frame(width: size, height: size)
        }
    }
    
    private func generateBlockiesImage(from address: String, size: Int) -> UIImage? {
        // Use a scale of 5 to get better quality for the 40pt size
        let scale = max(5, size / 8)
        let blockies = Blockies(seed: address.lowercased(), size: 8, scale: scale)
        return blockies.createImage()
    }
}

// MARK: - Parsed Content Models
enum ContentSegment: Identifiable {
    case text(String)
    case ethereumAddress(String)
    case eip155Token(chainId: String, tokenAddress: String, reference: Reference?)
    case url(String)
    case farcasterMention(String, reference: Reference?)
    
    var id: String {
        switch self {
        case .text(let content):
            return "text_\(content.hashValue)"
        case .ethereumAddress(let address):
            return "address_\(address)"
        case .eip155Token(let chainId, let tokenAddress, _):
            return "token_\(chainId)_\(tokenAddress)"
        case .url(let url):
            return "url_\(url)"
        case .farcasterMention(let username, _):
            return "farcaster_\(username)"
        }
    }
}

// MARK: - Content Parser
struct ContentParser {
    static func parseContent(_ content: String, references: [Reference]) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        
        // First, remove trailing references from content
        let trimmedContent = removeTrailingReferences(content, references: references)
        
        // Regex patterns
        let ethAddressPattern = #"0x[a-fA-F0-9]{40}"#
        let eip155Pattern = #"eip155:(\d+)/erc20:(0x[a-fA-F0-9]{40})"#
        let urlPattern = #"https?://[^\s]+"#
        
        // Create regex objects
        guard let ethRegex = try? NSRegularExpression(pattern: ethAddressPattern),
              let eip155Regex = try? NSRegularExpression(pattern: eip155Pattern),
              let urlRegex = try? NSRegularExpression(pattern: urlPattern) else {
            return [.text(trimmedContent)]
        }
        
        let nsString = trimmedContent as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        
        // Find all matches
        var allMatches: [(range: NSRange, type: String, reference: Reference?)] = []
        
        // First, add farcaster mentions from references with positions
        let farcasterReferences = references.filter { $0.type == "farcaster" && $0.position != nil }
        for farcasterRef in farcasterReferences {
            if let position = farcasterRef.position {
                let range = NSRange(location: position.start, length: position.end - position.start)
                // Ensure the range is valid for the trimmed content
                if range.location < nsString.length && range.location + range.length <= nsString.length {
                    allMatches.append((range: range, type: "farcaster", reference: farcasterRef))
                }
            }
        }
        
        // Find Ethereum addresses (but exclude those that are part of EIP155 patterns)
        ethRegex.enumerateMatches(in: trimmedContent, range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                // Check if this address is part of an EIP155 pattern
                let extendedStart = max(0, matchRange.location - 20)
                let extendedLength = min(nsString.length - extendedStart, matchRange.length + 40)
                let extendedRange = NSRange(location: extendedStart, length: extendedLength)
                let extendedText = nsString.substring(with: extendedRange)
                
                // If the address is part of an EIP155 pattern, skip it (EIP155 will handle it)
                if !extendedText.contains("eip155:") {
                    allMatches.append((range: matchRange, type: "eth", reference: nil))
                }
            }
        }
        
        // Find EIP155 tokens
        eip155Regex.enumerateMatches(in: trimmedContent, range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                allMatches.append((range: matchRange, type: "eip155", reference: nil))
            }
        }
        
        // Find URLs
        urlRegex.enumerateMatches(in: trimmedContent, range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                allMatches.append((range: matchRange, type: "url", reference: nil))
            }
        }
        
        // Sort matches by location
        allMatches.sort { $0.range.location < $1.range.location }
        
        var lastEndIndex = 0
        
        for match in allMatches {
            // Check if there's text before the match
            if match.range.location > lastEndIndex {
                let textRange = NSRange(location: lastEndIndex, length: match.range.location - lastEndIndex)
                let textContent = nsString.substring(with: textRange)
                
                // Check if the text immediately before the match ends with a non-space character
                if !textContent.isEmpty {
                    if textContent.hasSuffix(" ") || textContent.hasSuffix("\n") || textContent.hasSuffix("\t") {
                        // There's a space separator, keep the text
                        segments.append(.text(textContent))
                    } else {
                        // No space separator, find the last space/newline/tab and keep only text before it
                        if let lastSpaceIndex = textContent.lastIndex(where: { $0.isWhitespace }) {
                            let indexAfterSpace = textContent.index(after: lastSpaceIndex)
                            let textBeforeSpace = String(textContent[..<indexAfterSpace])
                            if !textBeforeSpace.isEmpty {
                                segments.append(.text(textBeforeSpace))
                            }
                            // The text after the last space gets replaced by the match
                        }
                        // If no space found, the entire text gets replaced by the match
                    }
                }
            }
            
            let matchedText = nsString.substring(with: match.range)
            
            if match.type == "eth" {
                segments.append(.ethereumAddress(matchedText))
            } else if match.type == "eip155" {
                // Parse EIP155 pattern
                if let eip155Match = try? eip155Regex.firstMatch(in: matchedText, range: NSRange(location: 0, length: matchedText.count)),
                   eip155Match.numberOfRanges >= 3 {
                    let chainId = (matchedText as NSString).substring(with: eip155Match.range(at: 1))
                    let tokenAddress = (matchedText as NSString).substring(with: eip155Match.range(at: 2))
                    
                    // Find matching reference using the address field
                    let matchingReference = references.first { reference in
                        reference.type == "erc20" && 
                        reference.address?.lowercased() == tokenAddress.lowercased()
                    }
                    
                    segments.append(.eip155Token(chainId: chainId, tokenAddress: tokenAddress, reference: matchingReference))
                }
            } else if match.type == "url" {
                segments.append(.url(matchedText))
            } else if match.type == "farcaster" {
                segments.append(.farcasterMention(matchedText, reference: match.reference))
            }
            
            lastEndIndex = match.range.location + match.range.length
        }
        
        // Add remaining text
        if lastEndIndex < nsString.length {
            let remainingText = nsString.substring(from: lastEndIndex)
            if !remainingText.isEmpty {
                segments.append(.text(remainingText))
            }
        }
        
        return segments.isEmpty ? [.text(trimmedContent)] : segments
    }
    
    private static func removeTrailingReferences(_ content: String, references: [Reference]) -> String {
        var currentContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Sort references by their end position in descending order to process from end to beginning
        let sortedReferences = references
            .compactMap { reference -> (reference: Reference, range: NSRange)? in
                guard let position = reference.position else { return nil }
                return (reference, NSRange(location: position.start, length: position.end - position.start))
            }
            .sorted { $0.range.location + $0.range.length > $1.range.location + $1.range.length }
        
        for (_, range) in sortedReferences {
            let nsContent = currentContent as NSString
            
            // Check if this reference is at the end of the content (allowing for trailing whitespace)
            let referenceEnd = range.location + range.length
            let contentLength = nsContent.length
            
            // Ensure the range is valid for the current content
            guard range.location < contentLength && referenceEnd <= contentLength else {
                continue
            }
            
            // Get the substring from reference end to content end
            let trailingText = nsContent.substring(from: referenceEnd)
            let trimmedTrailing = trailingText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If there's only whitespace after this reference, it's trailing - remove it
            if trimmedTrailing.isEmpty {
                currentContent = nsContent.substring(to: range.location).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Stop processing once we find a reference that's not trailing
                break
            }
        }
        
        return currentContent
    }
}

// MARK: - Parsed Content View
struct ParsedContentView: View {
    let segments: [ContentSegment]
    let isExpanded: Bool
    let maxLines: Int
    let maxHeight: CGFloat
    let onUserTap: ((String, String, String) -> Void)?
    
    init(segments: [ContentSegment], isExpanded: Bool, maxLines: Int, maxHeight: CGFloat, onUserTap: ((String, String, String) -> Void)? = nil) {
        self.segments = segments
        self.isExpanded = isExpanded
        self.maxLines = maxLines
        self.maxHeight = maxHeight
        self.onUserTap = onUserTap
    }
    
    var body: some View {
        let text = createAttributedText()
        
        // Use Text with attributed string for proper line limiting
        if #available(iOS 15.0, *) {
            Text(text)
                .font(.body)
                .lineLimit(isExpanded ? nil : maxLines)
                .frame(maxHeight: isExpanded ? nil : maxHeight, alignment: .top)
                .clipped()
        } else {
            // Fallback for older iOS versions
            VStack(alignment: .leading, spacing: 2) {
                ForEach(segments) { segment in
                    createSegmentView(segment)
                }
            }
            .lineLimit(isExpanded ? nil : maxLines)
            .frame(maxHeight: isExpanded ? nil : maxHeight, alignment: .top)
            .clipped()
        }
    }
    
    @available(iOS 15.0, *)
    private func createAttributedText() -> AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            switch segment {
            case .text(let content):
                result += AttributedString(content)
                
            case .ethereumAddress(let address):
                let truncated = truncateAddress(address)
                var addressAttr = AttributedString(truncated)
                addressAttr.foregroundColor = .blue
                addressAttr.underlineStyle = .single
                result += addressAttr
                
            case .eip155Token(_, let tokenAddress, let reference):
                let tokenText = getTokenText(tokenAddress: tokenAddress, reference: reference)
                var tokenAttr = AttributedString(tokenText)
                tokenAttr.foregroundColor = .blue
                tokenAttr.underlineStyle = .single
                result += tokenAttr
                
            case .url(let url):
                var urlAttr = AttributedString(url)
                urlAttr.foregroundColor = .blue
                urlAttr.underlineStyle = .single
                result += urlAttr
                
            case .farcasterMention(let mention, let reference):
                let displayText = reference?.username ?? mention
                var mentionAttr = AttributedString("@\(displayText)")
                // Only make it blue and underlined if we have a username to link to
                if reference?.username != nil {
                    mentionAttr.foregroundColor = .blue
                    mentionAttr.underlineStyle = .single
                }
                result += mentionAttr
            }
        }
        
        return result
    }
    
    @ViewBuilder
    private func createSegmentView(_ segment: ContentSegment) -> some View {
        switch segment {
        case .text(let content):
            Text(content)
                .font(.body)
                
        case .ethereumAddress(let address):
            Button(action: {
                onUserTap?(address, truncateAddress(address), address)
            }) {
                Text(truncateAddress(address))
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            
        case .eip155Token(let chainId, let tokenAddress, let reference):
            Button(action: {
                openBlockscan(chainId: chainId, tokenAddress: tokenAddress)
            }) {
                Text(getTokenText(tokenAddress: tokenAddress, reference: reference))
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            
        case .url(let url):
            Button(action: {
                openURL(url: url)
            }) {
                Text(url)
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
            .buttonStyle(.plain)
            
        case .farcasterMention(let mention, let reference):
            let displayText = reference?.username ?? mention
            
            // Only make it clickable if we have a username
            if reference?.username != nil {
                Button(action: {
                    if let username = reference?.username {
                        onUserTap?(username, "@\(username)", username)
                    }
                }) {
                    Text("@\(displayText)")
                        .font(.body)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
            } else {
                // Non-clickable text for FID-only mentions
                Text("@\(displayText)")
                    .font(.body)
            }
        }
    }
    
    private func getTokenText(tokenAddress: String, reference: Reference?) -> String {
        if let symbol = reference?.symbol {
            return "$\(symbol)"
        } else if let name = reference?.name {
            return "$\(name)"
        } else {
            // Show truncated address if no token info is found
            return truncateAddress(tokenAddress)
        }
    }
    
    private func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = String(address.prefix(6))  // 0x1234
        let suffix = String(address.suffix(4))  // abcd
        return "\(prefix)...\(suffix)"
    }
    
    private func openBasescan(address: String) {
        let url = "https://basescan.org/address/\(address)"
        if let urlObject = URL(string: url) {
            UIApplication.shared.open(urlObject)
        }
    }
    
    private func openBlockscan(chainId _: String, tokenAddress: String) {
        let explorerURL: String = "https://blockscan.com/address/\(tokenAddress)"
        
        if let url = URL(string: explorerURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(url: String) {
        if let urlObject = URL(string: url) {
            UIApplication.shared.open(urlObject)
        }
    }
    
    private func openFarcasterProfile(reference: Reference?) {
        guard let reference = reference,
              let username = reference.username else { return }
        
        if let url = URL(string: "https://farcaster.id/\(username)") {
            UIApplication.shared.open(url)
        }
    }
}

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
            // Skip farcaster references as they're now shown inline
            if reference.type == "farcaster" {
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

// MARK: - Reference Chip View
struct ReferenceChip: View {
    let reference: Reference
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForReferenceType(reference.type))
                .font(.caption)
            
            if let symbol = reference.symbol, reference.type == "erc20" {
                Text("$\(symbol)")
                    .font(.caption)
                    .lineLimit(1)
            } else if reference.type == "farcaster", let username = reference.username {
                Text("@\(username)")
                    .font(.caption)
                    .lineLimit(1)
            } else if let title = reference.title {
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
            handleTap()
        }
    }
    
    private func handleTap() {
        if reference.type == "webpage", let urlString = reference.url, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        } else if reference.type == "erc20", let address = reference.address {
            let chainId = reference.chainId ?? 8453 // Default to Base
            openBlockscan(chainId: String(chainId), tokenAddress: address)
        } else if reference.type == "ens", let urlString = reference.url, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        } else if reference.type == "farcaster", let username = reference.username {
            if let url = URL(string: "https://farcaster.xyz/\(username)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openBlockscan(chainId: String, tokenAddress: String) {
        // Map chain IDs to their respective block explorers
        let explorerURL: String
        switch chainId {
        case "1":
            explorerURL = "https://etherscan.io/token/\(tokenAddress)"
        case "8453":
            explorerURL = "https://basescan.org/token/\(tokenAddress)"
        case "137":
            explorerURL = "https://polygonscan.com/token/\(tokenAddress)"
        case "10":
            explorerURL = "https://optimistic.etherscan.io/token/\(tokenAddress)"
        case "42161":
            explorerURL = "https://arbiscan.io/token/\(tokenAddress)"
        default:
            explorerURL = "https://basescan.org/token/\(tokenAddress)" // Default to Basescan
        }
        
        if let url = URL(string: explorerURL) {
            UIApplication.shared.open(url)
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
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.clear)
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