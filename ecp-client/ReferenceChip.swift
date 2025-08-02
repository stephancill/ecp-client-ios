//
//  ReferenceChip.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

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