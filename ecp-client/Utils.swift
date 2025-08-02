//
//  Utils.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation
import Web3

struct Utils {
    /// Truncates an Ethereum address to show only the first 6 and last 4 characters
    /// - Parameter address: The full Ethereum address
    /// - Returns: Truncated address in format "0x1234...abcd"
    static func truncateAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = String(address.prefix(6))  // 0x1234
        let suffix = String(address.suffix(4))  // abcd
        return "\(prefix)...\(suffix)"
    }
}

@MainActor
class BalanceService: ObservableObject {
    @Published var balance: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let rpcURL = "https://mainnet.base.org"
    
    func fetchBalance(for address: String) async {
        guard !address.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Create JSON-RPC request
            let requestBody: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_getBalance",
                "params": [address, "latest"],
                "id": 1
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            guard let url = URL(string: rpcURL) else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let result = response?["result"] as? String {
                // Convert hex balance to decimal
                let balanceHex = String(result.dropFirst(2)) // Remove "0x" prefix
                let balanceDecimal = UInt64(balanceHex, radix: 16) ?? 0
                
                // Convert from Wei to ETH
                let ethBalance = Double(balanceDecimal) / pow(10, 18)
                
                // Format balance with appropriate precision
                if ethBalance >= 1 {
                    balance = String(format: "%.4f ETH", ethBalance)
                } else if ethBalance >= 0.0001 {
                    balance = String(format: "%.6f ETH", ethBalance)
                } else {
                    balance = String(format: "%.8f ETH", ethBalance)
                }
            } else if let error = response?["error"] as? [String: Any] {
                throw NSError(domain: "RPCError", code: 0, userInfo: [NSLocalizedDescriptionKey: error["message"] as? String ?? "Unknown error"])
            } else {
                throw NSError(domain: "RPCError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
        } catch {
            self.error = "Failed to fetch balance: \(error.localizedDescription)"
            balance = "Error"
        }
        
        isLoading = false
    }
}

@MainActor
class ApprovalService: ObservableObject {
    @Published var isApproved: Bool? = nil
    @Published var isLoading = false
    @Published var error: String?
    
    private let rpcURL = "https://mainnet.base.org"
    private let contractAddress = "0xb262C9278fBcac384Ef59Fc49E24d800152E19b1"
    private let functionSignature = "0xa389783e" // isApproved(address,address)
    
    func checkApproval(identityAddress: String, appAddress: String) async {
        guard !identityAddress.isEmpty && !appAddress.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Prepare the function call data
            // isApproved(address identityAddress, address app) returns bool
            // We need to pad the addresses to 32 bytes (64 hex chars)
            let identityAddressHex = String(identityAddress.dropFirst(2)) // Remove 0x prefix
            let appAddressHex = String(appAddress.dropFirst(2)) // Remove 0x prefix
            
            // Pad addresses to 32 bytes (64 hex chars) by adding zeros at the beginning
            let paddedIdentityAddress = String(repeating: "0", count: 64 - identityAddressHex.count) + identityAddressHex
            let paddedAppAddress = String(repeating: "0", count: 64 - appAddressHex.count) + appAddressHex
            
            let callData = functionSignature + paddedIdentityAddress + paddedAppAddress
            
            // Create JSON-RPC request
            let requestBody: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_call",
                "params": [
                    [
                        "to": contractAddress,
                        "data": callData
                    ],
                    "latest"
                ],
                "id": 1
            ]

            print("🔍 Request Body: \(requestBody)")
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            guard let url = URL(string: rpcURL) else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let result = response?["result"] as? String {
                // The result is a hex string representing a boolean
                // "0x0000000000000000000000000000000000000000000000000000000000000000" = false
                // "0x0000000000000000000000000000000000000000000000000000000000000001" = true
                let resultHex = String(result.dropFirst(2)) // Remove "0x" prefix
                let lastChar = resultHex.suffix(1)
                isApproved = lastChar == "1"
            } else if let error = response?["error"] as? [String: Any] {
                throw NSError(domain: "RPCError", code: 0, userInfo: [NSLocalizedDescriptionKey: error["message"] as? String ?? "Unknown error"])
            } else {
                throw NSError(domain: "RPCError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
        } catch {
            self.error = "Failed to check approval: \(error.localizedDescription)"
            isApproved = nil
        }
        
        isLoading = false
    }
} 
