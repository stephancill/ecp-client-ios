//
//  AvatarView.swift
//  ecp-client
//
//  Renders a user avatar preferring profile images (Farcaster/ENS) and
//  falling back to blockies for the wallet address.
//

import SwiftUI
import CachedAsyncImage

struct AvatarView: View {
    let address: String
    let size: CGFloat
    let ensAvatarUrl: String?
    let farcasterPfpUrl: String?

    var body: some View {
        if let image = dataURIImageIfAvailable() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let url = remoteImageURL() {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure(_):
                    BlockiesAvatarView(address: address, size: size)
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: size, height: size)
                @unknown default:
                    BlockiesAvatarView(address: address, size: size)
                }
            }
        } else {
            BlockiesAvatarView(address: address, size: size)
        }
    }

    private func remoteImageURL() -> URL? {
        // Prefer Farcaster pfp, then ENS avatar URL
        if let pfp = farcasterPfpUrl, let url = URL(string: pfp), url.scheme?.hasPrefix("http") == true {
            return url
        }
        if let ensUrl = ensAvatarUrl, let url = URL(string: ensUrl), url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }

    private func dataURIImageIfAvailable() -> UIImage? {
        // Support data:image/*;base64,xxxxx avatars (some ENS providers)
        if let ensUrl = ensAvatarUrl, ensUrl.hasPrefix("data:image") {
            return decodeDataURI(ensUrl)
        }
        if let pfp = farcasterPfpUrl, pfp.hasPrefix("data:image") {
            return decodeDataURI(pfp)
        }
        return nil
    }

    private func decodeDataURI(_ dataURI: String) -> UIImage? {
        // Expected format: data:image/png;base64,<DATA>
        guard let commaIndex = dataURI.firstIndex(of: ",") else { return nil }
        let base64Part = String(dataURI[dataURI.index(after: commaIndex)...])
        if let data = Data(base64Encoded: base64Part, options: [.ignoreUnknownCharacters]),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }
}

