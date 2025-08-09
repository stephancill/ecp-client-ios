//
//  AuthService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3
import CryptoKit
import Foundation

// MARK: - Auth Models
struct AuthNonce: Codable {
    let nonce: String
    let message: String
}

struct AuthVerification: Codable {
    let success: Bool
    let approved: Bool
    let token: String
}

struct AuthError: Codable {
    let error: String
}

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String?
    @Published var isApproved = false
    
    // MARK: - Private Properties
    private let baseURL: String = AppConfiguration.shared.baseURL
    private var appAddress: String?
    private var appPrivateKey: String?
    
    // MARK: - Initialization
    init() {
        loadCredentials()
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Authenticate the user using their app address and private key
    func authenticate() async {
        guard let appAddress = appAddress,
              let appPrivateKey = appPrivateKey else {
            authError = "App credentials not found. Please check settings."
            return
        }
        
        isLoading = true
        authError = nil
        
        do {
            // Step 1: Get nonce and SIWE message from server
            let nonceResponse = try await getNonce(address: appAddress)
            
            // Step 2: Sign the SIWE message
            let signature = try signMessage(nonceResponse.message, privateKey: appPrivateKey)
            
            // Step 3: Verify signature with server
            let authResult = try await verifySignature(message: nonceResponse.message, signature: signature)
            
            // Step 4: Store token and update state
            if authResult.success {
                try KeychainManager.storeJWTToken(authResult.token)
                isAuthenticated = true
                isApproved = authResult.approved
            } else {
                authError = "Authentication failed"
            }
            
        } catch {
            authError = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    /// Sign out the user by clearing stored tokens
    func signOut() async {
        isLoading = true
        
        do {
            // Call logout endpoint if we have a token
            if let token = try KeychainManager.retrieveJWTToken() {
                try await logout(token: token)
            }
        } catch {
            // Continue with local logout even if API call fails
            print("Logout API call failed: \(error)")
        }
        
        // Clear local state
        do {
            try KeychainManager.deleteJWTToken()
        } catch {
            print("Failed to delete JWT token: \(error)")
        }
        
        isAuthenticated = false
        isApproved = false
        isLoading = false
    }
    
    /// Get the current JWT token for API requests
    func getAuthToken() -> String? {
        do {
            return try KeychainManager.retrieveJWTToken()
        } catch {
            return nil
        }
    }

    /// Returns the derived app address used as user id for the backend
    /// This is used by clients to namespace per-user local state (e.g., last read timestamps)
    func getAppAddress() -> String? {
        return appAddress
    }
    
    /// Check if the current token is still valid
    func validateToken() async -> Bool {
        guard let token = getAuthToken() else { return false }
        
        do {
            let response = try await makeAuthenticatedRequest(
                url: "\(baseURL)/api/auth/me",
                method: "GET",
                token: token
            )
            
            return response.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCredentials() {
        do {
            appPrivateKey = try KeychainManager.retrievePrivateKey()
            if let privateKey = appPrivateKey {
                // Derive app address from private key
                let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
                let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
                appAddress = ethereumPrivateKey.address.hex(eip55: true)
            }
        } catch {
            print("Failed to load app credentials: \(error)")
        }
    }
    
    private func checkAuthenticationStatus() {
        // Check if we have a stored token
        if KeychainManager.hasJWTToken() {
            Task {
                let isValid = await validateToken()
                await MainActor.run {
                    isAuthenticated = isValid
                    if !isValid {
                        // Token is invalid, clear it
                        try? KeychainManager.deleteJWTToken()
                    }
                }
            }
        }
    }
    
    private func getNonce(address: String) async throws -> AuthNonce {
        let url = URL(string: "\(baseURL)/api/auth/nonce")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["address": address]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthServiceError.networkError("Failed to get nonce")
        }
        
        let nonceResponse = try JSONDecoder().decode(AuthNonce.self, from: data)
        return nonceResponse
    }
    
    private func signMessage(_ message: String, privateKey: String) throws -> String {
        let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
        let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
        
        // Apply EIP-191 message prefixing manually
        let messageData = message.data(using: .utf8)!
        let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)".data(using: .utf8)!
        let prefixedMessage = prefix + messageData
        let prefixedMessageBytes = Array(prefixedMessage) // Convert Data to [UInt8]
        
        // Sign the prefixed message hash
        let signature = try ethereumPrivateKey.sign(message: prefixedMessageBytes)
        
        // Convert to canonical signature format using Utils
        let canonicalSignature = Utils.toCanonicalSignature((v: signature.v, r: signature.r, s: signature.s))
        return canonicalSignature.toHexString()
    }
    
    private func verifySignature(message: String, signature: String) async throws -> AuthVerification {
        let url = URL(string: "\(baseURL)/api/auth/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "message": message,
            "signature": signature
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(AuthVerification.self, from: data)
        } else {
            let errorResponse = try? JSONDecoder().decode(AuthError.self, from: data)
            throw AuthServiceError.authenticationFailed(errorResponse?.error ?? "Unknown error")
        }
    }
    
    private func logout(token: String) async throws {
        let url = URL(string: "\(baseURL)/api/auth/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthServiceError.networkError("Logout failed")
        }
    }
    
    private func makeAuthenticatedRequest(url: String, method: String, token: String) async throws -> HTTPURLResponse {
        let requestUrl = URL(string: url)!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.networkError("Invalid response")
        }
        
        return httpResponse
    }
}

// MARK: - Auth Service Errors
enum AuthServiceError: Error, LocalizedError {
    case networkError(String)
    case authenticationFailed(String)
    case invalidCredentials
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .invalidCredentials:
            return "Invalid credentials"
        case .tokenExpired:
            return "Token expired"
        }
    }
}

