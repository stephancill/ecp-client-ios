//
//  ComposeCommentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

struct ComposeCommentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Text Editor with Avatar
                HStack(alignment: .top, spacing: 12) {
                    // Placeholder Avatar
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                    
                    // Text Editor
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $commentText)
                            .font(.body)
                            .frame(minHeight: 80)
                        
                        if commentText.isEmpty {
                            Text("What's your take?")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                // Character Count
                HStack {
                    Spacer()
                    Text("\(commentText.count)/500")
                        .font(.caption)
                        .foregroundColor(commentText.count > 500 ? .red : .secondary)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        postComment()
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting)
                    .opacity(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting ? 0.6 : 1.0)
                }
            }
        }
    }
    
    private func postComment() {
        isPosting = true
        
        // TODO: Implement actual comment posting to the API
        // For now, just simulate posting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPosting = false
            dismiss()
        }
    }
}



#Preview {
    ComposeCommentView()
} 
