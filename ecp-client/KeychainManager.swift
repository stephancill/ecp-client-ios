import Foundation
import Security

// MARK: - Keychain Manager
class KeychainManager {
    
    // MARK: - Constants
    private static let service = "com.ecp-client.keychain"
    private static let privateKeyAccount = "user_private_key"
    private static let identityAddressAccount = "user_identity_address"
    
    // MARK: - Errors
    enum KeychainError: Error, LocalizedError {
        case duplicateItem
        case unknown(OSStatus)
        case itemNotFound
        case invalidData
        
        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Private key already exists"
            case .unknown(let status):
                return "Unknown keychain error: \(status)"
            case .itemNotFound:
                return "Private key not found"
            case .invalidData:
                return "Invalid private key data"
            }
        }
    }
    
    // MARK: - Private Key Storage
    
    /// Stores a private key hex string in the keychain with iCloud sync
    /// - Parameter privateKeyHex: The private key as a hex string (with or without 0x prefix)
    /// - Throws: KeychainError if storage fails
    static func storePrivateKey(_ privateKeyHex: String) throws {
        // Clean the hex string (remove 0x prefix if present)
        let cleanHex = privateKeyHex.hasPrefix("0x") ? String(privateKeyHex.dropFirst(2)) : privateKeyHex
        
        // Validate hex string
        guard cleanHex.allSatisfy({ $0.isHexDigit }) else {
            throw KeychainError.invalidData
        }
        
        guard let data = cleanHex.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true, // Enable iCloud sync
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Retrieves the stored private key from the keychain
    /// - Returns: The private key as a hex string without 0x prefix
    /// - Throws: KeychainError if retrieval fails
    static func retrievePrivateKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyAccount,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: true, // Look for synced items
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let privateKeyHex = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return privateKeyHex
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Updates an existing private key in the keychain
    /// - Parameter privateKeyHex: The new private key as a hex string
    /// - Throws: KeychainError if update fails
    static func updatePrivateKey(_ privateKeyHex: String) throws {
        // Clean the hex string
        let cleanHex = privateKeyHex.hasPrefix("0x") ? String(privateKeyHex.dropFirst(2)) : privateKeyHex
        
        // Validate hex string
        guard cleanHex.allSatisfy({ $0.isHexDigit }) else {
            throw KeychainError.invalidData
        }
        
        guard let data = cleanHex.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyAccount,
            kSecAttrSynchronizable as String: true
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        
        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Removes the private key from the keychain
    /// - Throws: KeychainError if deletion fails
    static func deletePrivateKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyAccount,
            kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            break // Success or item didn't exist (both okay)
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Checks if a private key exists in the keychain
    /// - Returns: True if private key exists, false otherwise
    static func hasPrivateKey() -> Bool {
        do {
            _ = try retrievePrivateKey()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Identity Address Storage
    
    /// Stores an identity address in the keychain with iCloud sync
    /// - Parameter address: The Ethereum address as a string
    /// - Throws: KeychainError if storage fails
    static func storeIdentityAddress(_ address: String) throws {
        // Validate Ethereum address format
        let pattern = "^0x[a-fA-F0-9]{40}$"
        guard address.range(of: pattern, options: .regularExpression) != nil else {
            throw KeychainError.invalidData
        }
        
        guard let data = address.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAddressAccount,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: true, // Enable iCloud sync
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            // If item exists, update it
            try updateIdentityAddress(address)
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Retrieves the stored identity address from the keychain
    /// - Returns: The identity address as a string, or nil if not found
    /// - Throws: KeychainError if retrieval fails
    static func retrieveIdentityAddress() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAddressAccount,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: true, // Look for synced items
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let address = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return address
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Updates an existing identity address in the keychain
    /// - Parameter address: The new identity address
    /// - Throws: KeychainError if update fails
    static func updateIdentityAddress(_ address: String) throws {
        // Validate Ethereum address format
        let pattern = "^0x[a-fA-F0-9]{40}$"
        guard address.range(of: pattern, options: .regularExpression) != nil else {
            throw KeychainError.invalidData
        }
        
        guard let data = address.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAddressAccount,
            kSecAttrSynchronizable as String: true
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        
        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Removes the identity address from the keychain
    /// - Throws: KeychainError if deletion fails
    static func deleteIdentityAddress() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identityAddressAccount,
            kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            break // Success or item didn't exist (both okay)
        default:
            throw KeychainError.unknown(status)
        }
    }
    
    /// Checks if an identity address exists in the keychain
    /// - Returns: True if identity address exists, false otherwise
    static func hasIdentityAddress() -> Bool {
        do {
            return try retrieveIdentityAddress() != nil
        } catch {
            return false
        }
    }
}

// MARK: - Convenience Extensions
extension String {
    var isHexDigit: Bool {
        return self.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil
    }
} 