//
//  ContentParser.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

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