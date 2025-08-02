//
//  SettingsView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var privateKey: String = ""
    @State private var ethereumAddress: String = ""
    @State private var isPrivateKeyVisible = false
    @StateObject private var balanceService = BalanceService()
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("App Account"),
                    footer: Text("Your private key and derived Ethereum address used for posting comments on your behalf. Keep your private key secure.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Private Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    if isPrivateKeyVisible {
                                        Text(privateKey)
                                            .font(.system(.body, design: .monospaced))
                                            .textSelection(.enabled)
                                    } else {
                                        HStack {
                                            ForEach(0..<8, id: \.self) { _ in
                                                Circle()
                                                    .fill(Color.secondary)
                                                    .frame(width: 8, height: 8)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .allowsHitTesting(false)
                                
                                Spacer()
                                
                                Button(action: {
                                    isPrivateKeyVisible.toggle()
                                }) {
                                    Image(systemName: isPrivateKeyVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ethereum Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack {
                                Text(Utils.truncateAddress(ethereumAddress))
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Balance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            HStack {
                                if balanceService.isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading balance...")
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text(balanceService.balance.isEmpty ? "0 ETH" : balanceService.balance)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(balanceService.error != nil ? .red : .primary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    Task {
                                        await balanceService.fetchBalance(for: ethereumAddress)
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                }
                                .disabled(balanceService.isLoading)
                            }
                        }
                    }.contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = privateKey
                        }) {
                            Label("Copy Private Key", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            UIPasteboard.general.string = ethereumAddress
                        }) {
                            Label("Copy Address", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadPrivateKey()
        }
    }
    
    private func loadPrivateKey() {
        do {
            privateKey = try KeychainManager.retrievePrivateKey()
            deriveEthereumAddress()
        } catch {
            // Generate a new private key if none exists
            generateNewPrivateKey()
        }
    }
    
    private func deriveEthereumAddress() {
        guard !privateKey.isEmpty else { return }
        
        do {
            // Ensure the private key has the 0x prefix
            let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
            let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
            ethereumAddress = ethereumPrivateKey.address.hex(eip55: true)
            
            // Print the address for easy copying
            print("🔗 Ethereum Address: \(ethereumAddress)")
            
            // Fetch balance for the derived address
            Task {
                await balanceService.fetchBalance(for: ethereumAddress)
            }
        } catch {
            print("Failed to derive Ethereum address: \(error)")
            ethereumAddress = "Error deriving address"
        }
    }
    
    private func generateNewPrivateKey() {
        // Generate a random 32-byte private key
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        let privateKeyHex = bytes.map { String(format: "%02x", $0) }.joined()
        
        do {
            try KeychainManager.storePrivateKey(privateKeyHex)
            privateKey = privateKeyHex
            deriveEthereumAddress()
        } catch {
            // Handle error - could show an alert here
            print("Failed to store private key: \(error)")
        }
    }
}

#Preview("Settings") {
    SettingsView()
} 