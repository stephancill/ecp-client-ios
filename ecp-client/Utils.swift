//
//  Utils.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation

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
    
    static func displayName(ensName: String?, farcasterUsername: String?, fallbackAddress: String) -> String {
        if let name = ensName, !name.isEmpty { return name }
        if let uname = farcasterUsername, !uname.isEmpty { return uname }
        return truncateAddress(fallbackAddress)
    }
}

// MARK: - Data Extensions

extension Data {
    /// Initialize Data from a hex string
    /// - Parameter hex: Hex string (with or without 0x prefix)
    init(hex: String) {
        let cleanHex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var data = Data()
        var index = cleanHex.startIndex
        
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2, limitedBy: cleanHex.endIndex) ?? cleanHex.endIndex
            let byteString = String(cleanHex[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        
        self = data
    }
    
    /// Convert to hex string with 0x prefix
    func toHexString() -> String {
        return "0x" + map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Signature Utilities

extension Utils {
    /// Convert Web3 signature tuple to compact signature format
    /// According to EIP specification: [256-bit r value][1-bit yParity value][255-bit s value]
    /// - Parameter signature: Tuple containing (v, r, s) from Web3 signing
    /// - Returns: Compact signature as 64-byte Data
    static func toCompactSignature(_ signature: (v: UInt, r: [UInt8], s: [UInt8])) -> Data {
        // Normalize v from canonical 27/28 to yParity 0/1
        let yParity = signature.v >= 27 ? signature.v - 27 : signature.v
        
        // Convert r and s arrays to Data
        let rData = Data(signature.r)
        let sData = Data(signature.s)
        
        // Ensure r and s are exactly 32 bytes
        let r32 = rData.count == 32 ? rData : Data(count: 32 - rData.count) + rData
        let s32 = sData.count == 32 ? sData : Data(count: 32 - sData.count) + sData
        
        // Create yParityAndS according to spec: (yParity << 255) | s
        var yParityAndS = s32
        if yParity == 1 {
            // Set the top bit (bit 255) by setting the MSB of the first byte
            yParityAndS[0] |= 0x80
        }
        
        // Combine r (32 bytes) + yParityAndS (32 bytes) = 64 bytes total
        var compactSignature = Data()
        compactSignature.append(r32)
        compactSignature.append(yParityAndS)
        
        return compactSignature
    }
    
    /// Convert compact signature back to canonical format for verification
    /// - Parameter compactSig: 64-byte compact signature
    /// - Returns: Tuple containing (v, r, s) in canonical format
    static func fromCompactSignature(_ compactSig: Data) -> (v: UInt, r: Data, s: Data) {
        guard compactSig.count == 64 else {
            fatalError("Compact signature must be exactly 64 bytes")
        }
        
        // Extract r (first 32 bytes)
        let r = compactSig.prefix(32)
        
        // Extract yParityAndS (last 32 bytes)
        let yParityAndS = compactSig.suffix(32)
        
        // Extract yParity from the top bit
        let yParity = (yParityAndS[0] & 0x80) != 0 ? 1 : 0
        
        // Extract s by clearing the top bit
        var s = yParityAndS
        s[0] &= 0x7F  // Clear the MSB
        
        // Convert yParity to canonical v (27/28)
        let v = UInt(yParity + 27)
        
        return (v: v, r: r, s: s)
    }

    static func toCanonicalSignature(_ signature: (v: UInt, r: [UInt8], s: [UInt8])) -> Data {
        // Ensure r, s are 32-byte each
        let rData = Data(signature.r)
        let sData = Data(signature.s)
        let r32 = rData.count == 32 ? rData : Data(count: 32 - rData.count) + rData
        let s32 = sData.count == 32 ? sData : Data(count: 32 - sData.count) + sData
        
        // Normalize v to 27/28 (Ethereum canonical)
        let vCanonical: UInt8
        if signature.v == 0 || signature.v == 27 {
            vCanonical = 27
        } else if signature.v == 1 || signature.v == 28 {
            vCanonical = 28
        } else {
            // If an unexpected value is supplied, keep the lower 8-bits but warn in debug
            #if DEBUG
            print("⚠️ Unexpected v value \(signature.v); using lower-byte \(signature.v & 0xFF)")
            #endif
            vCanonical = UInt8(signature.v & 0xFF)
        }
        
        // Assemble canonical RSV (65 bytes): r ‖ s ‖ v
        var data = Data()
        data.append(r32)
        data.append(s32)
        data.append(vCanonical)
        return data
    }

    /// Convenience: Compact → canonical (65-byte) conversion
    static func compactToCanonical(_ compactSig: Data) -> Data {
        let canonical = fromCompactSignature(compactSig)
        return toCanonicalSignature((v: canonical.v, r: Array(canonical.r), s: Array(canonical.s)))
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
