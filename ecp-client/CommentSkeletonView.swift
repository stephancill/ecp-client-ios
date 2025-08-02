//
//  CommentSkeletonView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

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