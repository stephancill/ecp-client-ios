//
//  ChannelsService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Foundation

// MARK: - Data Models
struct ChannelsResponse: Codable {
    let results: [Channel]
    let pagination: ChannelPagination
}

struct Channel: Codable, Identifiable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let owner: String
    let name: String
    let description: String
    let metadata: [String] // Empty array in API response
    let hook: String?
    let chainId: Int
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: createdAt) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.dateTimeStyle = .named
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return createdAt
    }
    
    var truncatedOwner: String {
        guard owner.count > 10 else { return owner }
        let start = String(owner.prefix(6))
        let end = String(owner.suffix(4))
        return "\(start)...\(end)"
    }
}

struct ChannelPagination: Codable {
    let limit: Int
    let hasNext: Bool
    let hasPrevious: Bool
    let startCursor: String?
    let endCursor: String?
}

// MARK: - Channels Service
class ChannelsService: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    
    // Cache for individual channels
    @Published private var channelCache: [String: Channel] = [:]
    
    private var currentPagination: ChannelPagination?
    private var endCursor: String?
    private let chainId: Int
    
    init(chainId: Int = 8453) {
        self.chainId = chainId
    }
    
    // MARK: - Fetch All Channels
    
    // Async version for SwiftUI's refreshable
    @MainActor
    func refreshChannels() async {
        isRefreshing = true
        endCursor = nil
        currentPagination = nil
        errorMessage = nil
        
        let urlString = "https://api.ethcomments.xyz/api/channels?chainId=\(chainId)&limit=50&sort=desc"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isRefreshing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let channelsResponse = try JSONDecoder().decode(ChannelsResponse.self, from: data)
            
            self.channels = channelsResponse.results
            self.currentPagination = channelsResponse.pagination
            self.endCursor = channelsResponse.pagination.hasNext ? channelsResponse.pagination.endCursor : nil
            
            // Update cache with fetched channels
            for channel in channelsResponse.results {
                self.channelCache[channel.id] = channel
            }
            
        } catch {
            self.errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
        
        isRefreshing = false
    }
    
    func fetchChannels(refresh: Bool = false) {
        let isRefreshRequest = refresh
        
        if refresh {
            isRefreshing = true
            endCursor = nil
            currentPagination = nil
        }
        
        isLoading = !refresh && channels.isEmpty
        errorMessage = nil
        
        let baseURL = "https://api.ethcomments.xyz/api/channels?chainId=\(chainId)&limit=50&sort=desc"
        let urlString = endCursor != nil ? "\(baseURL)&cursor=\(endCursor!)" : baseURL
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.isLoadingMore = false
                self?.isRefreshing = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let channelsResponse = try JSONDecoder().decode(ChannelsResponse.self, from: data)
                    
                    if isRefreshRequest || self?.channels.isEmpty == true {
                        self?.channels = channelsResponse.results
                    } else {
                        // Append new channels, avoiding duplicates
                        let newChannels = channelsResponse.results.filter { newChannel in
                            !(self?.channels.contains { $0.id == newChannel.id } ?? false)
                        }
                        self?.channels.append(contentsOf: newChannels)
                    }
                    
                    // Update cache with fetched channels
                    for channel in channelsResponse.results {
                        self?.channelCache[channel.id] = channel
                    }
                    
                    self?.currentPagination = channelsResponse.pagination
                    self?.endCursor = channelsResponse.pagination.hasNext ? channelsResponse.pagination.endCursor : nil
                } catch {
                    self?.errorMessage = "Failed to decode data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Individual Channel
    
    func fetchChannel(id: String, completion: @escaping (Channel?) -> Void) {
        // Check cache first
        if let cachedChannel = channelCache[id] {
            completion(cachedChannel)
            return
        }
        
        let urlString = "https://api.ethcomments.xyz/api/channels/\(id)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching channel \(id): \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    let channel = try JSONDecoder().decode(Channel.self, from: data)
                    
                    // Cache the channel
                    self?.channelCache[id] = channel
                    completion(channel)
                } catch {
                    print("Failed to decode channel \(id): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // Async version for individual channel fetching
    func fetchChannel(id: String) async -> Channel? {
        // Check cache first
        if let cachedChannel = channelCache[id] {
            return cachedChannel
        }
        
        let urlString = "https://api.ethcomments.xyz/api/channels/\(id)"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let channel = try JSONDecoder().decode(Channel.self, from: data)
            
            await MainActor.run {
                // Cache the channel
                self.channelCache[id] = channel
            }
            
            return channel
        } catch {
            print("Error fetching channel \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Pagination Support
    
    func loadMoreChannelsIfNeeded() {
        guard !isLoading && !isLoadingMore && canLoadMore else { return }
        
        isLoadingMore = true
        fetchChannels(refresh: false)
    }
    
    var canLoadMore: Bool {
        return currentPagination?.hasNext == true && endCursor != nil
    }
    
    // MARK: - Cache Management
    
    func getCachedChannel(id: String) -> Channel? {
        return channelCache[id]
    }
    
    func clearCache() {
        channelCache.removeAll()
    }
}