//
//  ParsedContentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

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