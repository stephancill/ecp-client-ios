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
    @State private var identityAddress: String? = nil
    @State private var showConnectWallet = false
    @State private var showEnterAddress = false
    @StateObject private var balanceService = BalanceService()
    @StateObject private var approvalService = ApprovalService()
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Identity"),
                    footer: Text("Your Ethereum address for posting comments on behalf of to the Ethereum Comments Protocol. This can be connected from a wallet or manually entered.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
                    if let address = identityAddress {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(Utils.truncateAddress(address))
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Approval Status")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                HStack {
                                    if approvalService.isLoading {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Checking approval...")
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        HStack(spacing: 8) {
                                            Image(systemName: approvalService.isApproved == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(approvalService.isApproved == true ? .green : .red)
                                            Text(approvalService.isApproved == true ? "Approved" : "Not Approved")
                                                .foregroundColor(approvalService.isApproved == true ? .green : .red)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await approvalService.checkApproval(identityAddress: address, appAddress: ethereumAddress)
                                        }
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(approvalService.isLoading)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Identity Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                }
                
                if identityAddress != nil {
                    Section {
                        Button(action: {
                            identityAddress = nil
                            // Remove from storage
                            do {
                                try KeychainManager.deleteIdentityAddress()
                                print("🗑️ Removed identity address from storage")
                            } catch {
                                print("Failed to remove identity address: \(error)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Disconnect Identity")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } header: {
                        Text("Identity Management")
                    } footer: {
                        Text("Disconnect your identity address to remove it from this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if identityAddress == nil {
                    Section {
                        Button(action: {
                            showConnectWallet = true
                        }) {
                            HStack {
                                Image(systemName: "wallet.pass")
                                    .foregroundColor(.blue)
                                Text("Connect Wallet")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Wallet Connection")
                    } footer: {
                        Text("Connect your wallet to post comments on behalf of to the Ethereum Comments Protocol.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Button(action: {
                            showEnterAddress = true
                        }) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .foregroundColor(.blue)
                                Text("Enter Approved Address")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Manual Entry")
                    } footer: {
                        Text("Enter an approved Ethereum address to post comments on behalf of to the Ethereum Comments Protocol.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
        .sheet(isPresented: $showConnectWallet) {
            ConnectWalletView(identityAddress: $identityAddress)
        }
        .sheet(isPresented: $showEnterAddress) {
            EnterAddressView(identityAddress: $identityAddress)
        }
        .onAppear {
            loadPrivateKey()
            loadIdentityAddress()
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
            
            // Check approval status if identity address exists
            if let identityAddress = identityAddress {
                Task {
                    await approvalService.checkApproval(identityAddress: identityAddress, appAddress: ethereumAddress)
                }
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
    
    private func loadIdentityAddress() {
        do {
            identityAddress = try KeychainManager.retrieveIdentityAddress()
            if let address = identityAddress {
                print("🔗 Loaded Identity Address: \(Utils.truncateAddress(address))")
                
                // Check approval status when identity is loaded
                Task {
                    await approvalService.checkApproval(identityAddress: address, appAddress: ethereumAddress)
                }
            } else {
                print("No identity address found in storage.")
            }
        } catch {
            print("Failed to load identity address: \(error)")
        }
    }
}

struct ConnectWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var identityAddress: String?
    @State private var isConnecting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Connect Wallet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Connect your wallet to verify your identity. This will allow you to sign messages and verify your Ethereum address.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        connectWallet()
                    }) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "wallet.pass")
                            }
                            Text(isConnecting ? "Connecting..." : "Connect Wallet")
                        }
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isConnecting)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func connectWallet() {
        isConnecting = true
        
        // Simulate wallet connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // For demo purposes, use a sample address
            // In a real app, this would integrate with WalletConnect or similar
            let sampleAddress = "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
            identityAddress = sampleAddress
            
            // Persist the address
            do {
                try KeychainManager.storeIdentityAddress(sampleAddress)
                print("🔗 Persisted Wallet Address: \(Utils.truncateAddress(sampleAddress))")
            } catch {
                print("Failed to persist wallet address: \(error)")
            }
            
            isConnecting = false
            dismiss()
        }
    }
}

struct EnterAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var identityAddress: String?
    @State private var addressInput = ""
    @State private var isValidAddress = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Enter Ethereum Address")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter an approved Ethereum address to verify your identity. This address will be used for identity verification.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ethereum Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("0x...", text: $addressInput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onChange(of: addressInput) { newValue in
                            validateAddress(newValue)
                        }
                    
                    if !addressInput.isEmpty && !isValidAddress {
                        Text("Please enter a valid Ethereum address")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        if isValidAddress {
                            identityAddress = addressInput
                            persistIdentityAddress(addressInput)
                            dismiss()
                        }
                    }) {
                        Text("Use This Address")
                            .font(.system(.body, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValidAddress ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isValidAddress)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Enter Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func validateAddress(_ address: String) {
        // Basic Ethereum address validation
        let pattern = "^0x[a-fA-F0-9]{40}$"
        isValidAddress = address.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func persistIdentityAddress(_ address: String) {
        do {
            try KeychainManager.storeIdentityAddress(address)
            print("�� Persisted Identity Address: \(Utils.truncateAddress(address))")
        } catch {
            print("Failed to persist identity address: \(error)")
        }
    }
}

#Preview("Settings") {
    SettingsView()
} 