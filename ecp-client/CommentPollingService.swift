//
//  CommentPollingService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation
import SwiftUI

@MainActor
class CommentPollingService: ObservableObject {
    @Published var isPolling = false
    @Published var pollingError: String?
    
    private var pollingTask: Task<Void, Never>?
    private let maxAttempts = 30 // 30 seconds with 1-second intervals
    private let pollingInterval: TimeInterval = 1.0
    
    func startPolling(commentId: String, onSuccess: @escaping () -> Void, onTimeout: @escaping () -> Void) {
        stopPolling() // Stop any existing polling
        
        isPolling = true
        pollingError = nil
        
        pollingTask = Task<Void, Never> {
            var attempts = 0
            
            while attempts < maxAttempts {
                // Check if task was cancelled
                if Task.isCancelled {
                    return
                }
                
                attempts += 1
                
                do {
                    let url = URL(string: "https://api.ethcomments.xyz/api/comments/\(commentId)?chainId=8453")!
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "accept")
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            // Comment found! Trigger success callback
                            await MainActor.run {
                                self.isPolling = false
                                onSuccess()
                            }
                            return
                        } else if httpResponse.statusCode == 404 {
                            // Comment not found yet, continue polling
                            if attempts < maxAttempts {
                                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
                            }
                        } else {
                            // Unexpected status code
                            await MainActor.run {
                                self.pollingError = "Unexpected response: \(httpResponse.statusCode)"
                                self.isPolling = false
                            }
                            return
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.pollingError = "Polling error: \(error.localizedDescription)"
                        self.isPolling = false
                    }
                    return
                }
            }
            
            // Max attempts reached
            await MainActor.run {
                self.pollingError = "Comment not found after \(self.maxAttempts) attempts (30 seconds)"
                self.isPolling = false
                onTimeout()
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        pollingError = nil
    }
    
    deinit {
        pollingTask?.cancel()
        pollingTask = nil
    }
} 