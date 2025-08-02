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
