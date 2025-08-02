//
//  BlockiesAvatarView.swift
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