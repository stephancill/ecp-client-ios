//
//  ParsedContentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import CachedAsyncImage

// MARK: - Parsed Content Result
struct ParsedContentResult {
    let textSegments: [ContentSegment]
    let imageReferences: [Reference]
}

// MARK: - Parsed Content View
struct ParsedContentView: View {
    let segments: [ContentSegment]
    let maxLines: Int
    let onUserTap: ((String, String, String) -> Void)?
    @State private var showingImageModal = false
    @State private var selectedImageURL: URL?
    @State private var isTruncated: Bool = false
    @State private var forceFullText: Bool = false
    
    // Computed property to separate text and image segments
    private var parsedResult: ParsedContentResult {
        let textSegments = segments.filter { segment in
            switch segment {
            case .image:
                return false
            default:
                return true
            }
        }
        
        let imageReferences = segments.compactMap { segment in
            switch segment {
            case .image(let reference):
                return reference
            default:
                return nil
            }
        }
        
        return ParsedContentResult(textSegments: textSegments, imageReferences: imageReferences)
    }
    
    init(segments: [ContentSegment], maxLines: Int, onUserTap: ((String, String, String) -> Void)? = nil) {
        self.segments = segments
        self.maxLines = maxLines
        self.onUserTap = onUserTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text content with truncation detection and internal show more/less
            Group {
                if forceFullText {
                    Text(.init(createMarkdownText()))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    TruncableText(
                        text: Text(.init(createMarkdownText())),
                        lineLimit: maxLines
                    ) { truncated in
                        isTruncated = truncated
                    }
                }
            }
            .font(.body)
            .environment(\.openURL, OpenURLAction { url in
                handleURLTap(url)
                return .handled
            })

            if (isTruncated || forceFullText) {
                Button(action: {
                    forceFullText.toggle()
                }) {
                    Text(forceFullText ? "Show less" : "Show more")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Images below text content
            if !parsedResult.imageReferences.isEmpty {
                ForEach(parsedResult.imageReferences.indices, id: \.self) { index in
                    let imageReference = parsedResult.imageReferences[index]
                    if let urlString = imageReference.url, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 200)
                                .clipped()  
                                .cornerRadius(12)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 200)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func createMarkdownText() -> String {
        var result = ""
        
        for segment in parsedResult.textSegments {
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
                
            case .image:
                // Images are handled separately in the view, this case should not occur in textSegments
                break
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

// MARK: - Truncation Helpers
// Source: https://www.fivestars.blog/articles/trucated-text/
struct TruncableText: View {
    let text: Text
    let lineLimit: Int?
    @State private var intrinsicSize: CGSize = .zero
    @State private var truncatedSize: CGSize = .zero
    let isTruncatedUpdate: (_ isTruncated: Bool) -> Void

    var body: some View {
        text
            .lineLimit(lineLimit)
            .readSize { size in
                truncatedSize = size
                isTruncatedUpdate(truncatedSize != intrinsicSize)
            }
            .background(
                text
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .readSize { size in
                        intrinsicSize = size
                        isTruncatedUpdate(truncatedSize != intrinsicSize)
                    }
            )
    }
}

public extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
