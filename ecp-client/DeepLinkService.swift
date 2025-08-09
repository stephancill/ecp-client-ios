//
//  DeepLinkService.swift
//  ecp-client
//
//  Created by Assistant on 2025/08/09.
//

import Foundation

@MainActor
class DeepLinkService: ObservableObject {
    enum Route: Equatable, Identifiable {
        case comment(id: String, focusReplyId: String?, parentId: String?)

        var id: String {
            switch self {
            case .comment(let id, let focus, let parent):
                return ["comment", id, focus ?? "", parent ?? ""].joined(separator: ":")
            }
        }
    }

    @Published var route: Route? = nil
    @Published var pendingRoute: Route? = nil

    func open(url: URL) {
        // Handle custom scheme: ecp-client://comment/<id>
        if url.host == "comment" {
            let parts = url.pathComponents.filter { $0 != "/" }
            if let id = parts.first { self.route = .comment(id: id, focusReplyId: nil, parentId: nil) }
        }
    }

    func openFromNotification(userInfo: [AnyHashable: Any]) {
        // Expect keys: type (reply|like), commentId, parentId
        let type = userInfo["type"] as? String
        let commentId = userInfo["commentId"] as? String
        let parentId = userInfo["parentId"] as? String

        switch type?.lowercased() {
        case "reply":
            if let replyId = commentId {
                // Show the thread anchored to the reply
                self.route = .comment(id: replyId, focusReplyId: replyId, parentId: parentId)
            }
        case "like":
            if let pId = parentId ?? commentId {
                // Open parent
                self.route = .comment(id: pId, focusReplyId: nil, parentId: nil)
            }
        default:
            if let id = commentId {
                self.route = .comment(id: id, focusReplyId: nil, parentId: parentId)
            }
        }
    }
}

