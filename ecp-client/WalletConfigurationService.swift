//
//  WalletConfigurationService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation
import CoinbaseWalletSDK

// MARK: - Supported Wallets
enum SupportedWallet: String, CaseIterable {
    case rainbow = "rainbow"
    case coinbase = "coinbase"
    
    var displayName: String {
        switch self {
        case .rainbow:
            return "Rainbow"
        case .coinbase:
            return "Coinbase Wallet"
        }
    }
    
    var hostURL: String {
        switch self {
        case .rainbow:
            return "https://rnbwapp.com/wsegue"
        case .coinbase:
            return "https://wallet.coinbase.com/wsegue"
        }
    }
    
    var iconName: String {
        switch self {
        case .rainbow:
            return "wallet.pass.fill"
        case .coinbase:
            return "wallet.pass.fill"
        }
    }
}

// MARK: - Wallet Configuration Service
class WalletConfigurationService: ObservableObject {
    static let shared = WalletConfigurationService()
    
    @Published var selectedWallet: SupportedWallet = .coinbase
    
    private let callbackURL = URL(string: "ecp-client://mycallback")!
    
    private init() {
        loadSelectedWallet()
    }
    
    // MARK: - Public Methods
    
    /// Configure the CoinbaseWalletSDK with the selected wallet's host URL
    /// This should only be called once during app initialization
    func configureCoinbaseSDK() {
        CoinbaseWalletSDK.configure(
            host: URL(string: selectedWallet.hostURL)!,
            callback: callbackURL
        )
        print("🔧 Configured CoinbaseWalletSDK with \(selectedWallet.displayName) host: \(selectedWallet.hostURL)")
    }
    
    /// Check if the current wallet selection differs from what was used during SDK configuration
    var needsAppRestart: Bool {
        guard let configuredWallet = UserDefaults.standard.string(forKey: "configuredWallet") else {
            return false
        }
        return configuredWallet != selectedWallet.rawValue
    }
    
    /// Mark the current wallet as configured (called after SDK configuration)
    func markWalletAsConfigured() {
        UserDefaults.standard.set(selectedWallet.rawValue, forKey: "configuredWallet")
        print("✅ Marked \(selectedWallet.displayName) as configured")
    }
    
    /// Set the selected wallet (will require app restart if different from configured)
    func setSelectedWallet(_ wallet: SupportedWallet) {
        selectedWallet = wallet
        saveSelectedWallet()
        print("🔄 Selected wallet changed to: \(wallet.displayName)")
    }
    
    // MARK: - Private Methods
    
    private func saveSelectedWallet() {
        UserDefaults.standard.set(selectedWallet.rawValue, forKey: "selectedWallet")
    }
    
    private func loadSelectedWallet() {
        if let savedWallet = UserDefaults.standard.string(forKey: "selectedWallet"),
           let wallet = SupportedWallet(rawValue: savedWallet) {
            selectedWallet = wallet
        }
    }
} 
