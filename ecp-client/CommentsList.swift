//
//  CommentsList.swift
//  ecp-client
//
//  Created by Assistant on 2025/08/11.
//

import SwiftUI

struct CommentsList: View {
    let comments: [Comment]
    let currentUserAddress: String?
    let channelsService: ChannelsService?
    var onCommentDeleted: (() -> Void)? = nil
    var onAppearLast: (() -> Void)? = nil
    var onReplyTapped: ((Comment) -> Void)? = nil

    var body: some View {
        ForEach(comments) { comment in
            VStack(spacing: 0) {
                CommentRowView(
                    comment: comment,
                    currentUserAddress: currentUserAddress,
                    channelsService: channelsService,
                    onCommentDeleted: onCommentDeleted,
                    onReplyTapped: onReplyTapped
                )
                Divider()
                    .background(Color(.separator))
                    .opacity(0.6)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .onAppear {
                if comment.id == comments.last?.id {
                    onAppearLast?()
                }
            }
        }
    }
}

