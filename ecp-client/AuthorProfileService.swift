//
//  AuthorProfileService.swift
//  ecp-client
//
//  Fetches author profiles (ENS/Farcaster) from the public ECP API.
//

import Foundation

@MainActor
final class AuthorProfileService: ObservableObject {
    static let shared = AuthorProfileService()

    private var addressToProfileCache: [String: AuthorProfile] = [:]
    private var prefetchedImageURLs: Set<String> = []

    func cachedProfile(for address: String) -> AuthorProfile? {
        return addressToProfileCache[address.lowercased()]
    }

    func fetch(address: String) async throws -> AuthorProfile {
        let normalized = address.lowercased()
        if let cached = addressToProfileCache[normalized] { return cached }

        // Public indexer endpoint
        let urlString = "https://api.ethcomments.xyz/api/authors/\(address)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)

        // Try to decode directly as AuthorProfile first
        if let profile = try? JSONDecoder().decode(AuthorProfile.self, from: data) {
            addressToProfileCache[normalized] = profile
            prefetchImageIfPossible(profile)
            return profile
        }

        // Some deployments may wrap the profile under different keys
        struct AuthorProfileWrapper: Codable { let author: AuthorProfile?; let data: AuthorProfile? }
        if let wrapper = try? JSONDecoder().decode(AuthorProfileWrapper.self, from: data),
           let profile = wrapper.author ?? wrapper.data {
            addressToProfileCache[normalized] = profile
            prefetchImageIfPossible(profile)
            return profile
        }

        // Fallback: minimally parse known fields if structure differs
        let fallback = AuthorProfile(address: address, ens: nil, farcaster: nil)
        addressToProfileCache[normalized] = fallback
        return fallback
    }

    private func prefetchImageIfPossible(_ profile: AuthorProfile) {
        // Prefer Farcaster pfp, then ENS avatar URL
        let urlString: String? = profile.farcaster?.pfpUrl?.hasPrefix("http") == true
            ? profile.farcaster?.pfpUrl
            : (profile.ens?.avatarUrl?.hasPrefix("http") == true ? profile.ens?.avatarUrl : nil)
        guard let urlString, prefetchedImageURLs.contains(urlString) == false, let url = URL(string: urlString) else { return }
        prefetchedImageURLs.insert(urlString)
        // Fire-and-forget; allow URLCache to store the response for CachedAsyncImage reuse
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
}

