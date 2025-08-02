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
        Text(.init(createMarkdownText()))
            .font(.body)
            .lineLimit(isExpanded ? nil : maxLines)
            .frame(maxHeight: isExpanded ? nil : maxHeight, alignment: .top)
            .clipped()
            .environment(\.openURL, OpenURLAction { url in
                handleURLTap(url)
                return .handled
            })
    }
    
    private func createMarkdownText() -> String {
        var result = ""
        
        for segment in segments {
            switch segment {
            case .text(let content):
                result += content
                
            case .ethereumAddress(let address):
                let truncated = truncateAddress(address)
                result += "[\(truncated)](blockscan://address/\(address))"
                
            case .eip155Token(_, let tokenAddress, let reference):
                let tokenText = getTokenText(tokenAddress: tokenAddress, reference: reference)
                result += "[\(tokenText)](blockscan://token/\(tokenAddress))"
                
            case .url(let url):
                result += "[\(url)](\(url))"
                
            case .farcasterMention(let mention, let reference):
                let displayText = reference?.username ?? mention
                if let username = reference?.username {
                    result += "[@\(displayText)](farcaster://user/\(username))"
                } else {
                    result += "@\(displayText)"
                }
                
            case .ensMention(let mention, let reference):
                let displayText = reference?.name ?? mention
                if let urlString = reference?.url {
                    result += "[@\(displayText)](ens://\(urlString))"
                } else {
                    result += "@\(displayText)"
                }
            }
        }
        
        return result
    }
    
    private func handleURLTap(_ url: URL) {
        let urlString = url.absoluteString
        
        if urlString.hasPrefix("blockscan://address/") {
            let address = String(urlString.dropFirst("blockscan://address/".count))
            openBlockscan(address: address)
        } else if urlString.hasPrefix("blockscan://token/") {
            let tokenAddress = String(urlString.dropFirst("blockscan://token/".count))
            openBlockscan(address: tokenAddress)
        } else if urlString.hasPrefix("farcaster://user/") {
            let username = String(urlString.dropFirst("farcaster://user/".count))
            openFarcasterProfile(username: username)
        } else if urlString.hasPrefix("ens://") {
            let ensUrl = String(urlString.dropFirst("ens://".count))
            openURL(url: ensUrl)
        } else {
            // Handle regular URLs
            openURL(url: urlString)
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
    
    private func openBlockscan(address: String) {
        let explorerURL: String = "https://blockscan.com/address/\(address)"
        
        if let url = URL(string: explorerURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openURL(url: String) {
        if let urlObject = URL(string: url) {
            UIApplication.shared.open(urlObject)
        }
    }
    
    private func openFarcasterProfile(username: String) {
        if let url = URL(string: "https://farcaster.id/\(username)") {
            UIApplication.shared.open(url)
        }
    }
} 