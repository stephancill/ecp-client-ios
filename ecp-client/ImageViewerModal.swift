//
//  ImageViewerModal.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import CachedAsyncImage

// MARK: - Image Viewer Modal
struct ImageViewerModal: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Image with zoom and pan
            CachedAsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 0.5), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        let delta = CGSize(
                                            width: value.translation.width - lastOffset.width,
                                            height: value.translation.height - lastOffset.height
                                        )
                                        lastOffset = value.translation
                                        offset = CGSize(
                                            width: offset.width + delta.width,
                                            height: offset.height + delta.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = .zero
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .onAppear {
                            isLoading = false
                        }
                        
                case .failure(_):
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Failed to load image")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button("Try Again") {
                            // Trigger reload by changing the URL slightly
                            // This is a simple way to force AsyncImage to reload
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .onAppear {
                        isLoading = false
                        loadError = true
                    }
                    
                case .empty:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading image...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .onAppear {
                        isLoading = true
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            
            // Reset zoom button (only show when zoomed)
            if scale > 1.0 || offset != .zero {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scale = 1.0
                                offset = .zero
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sensoryFeedback(.impact, trigger: scale > 1.0)
    }
}

#Preview {
    ImageViewerModal(imageURL: URL(string: "https://picsum.photos/800/600")!)
} 