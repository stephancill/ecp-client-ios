//
//  SettingsView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3
import CoinbaseWalletSDK


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var privateKey: String = ""
    @State private var ethereumAddress: String = ""
    @State private var isPrivateKeyVisible = false
    @State private var identityAddress: String? = nil
    @State private var showConnectWallet = false
    @State private var showEnterAddress = false
    @State private var isApprovingIdentity = false
    @State private var approvalError: String?
    @State private var showApprovalError = false
    @StateObject private var balanceService = BalanceService()
    @StateObject private var commentsService = CommentsContractService()
    
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
                                    if commentsService.isLoading {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Checking approval...")
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        HStack(spacing: 8) {
                                            Image(systemName: commentsService.isApproved == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(commentsService.isApproved == true ? .green : .red)
                                            Text(commentsService.isApproved == true ? "Approved" : "Not Approved")
                                                .foregroundColor(commentsService.isApproved == true ? .green : .red)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await commentsService.checkApproval(identityAddress: address, appAddress: ethereumAddress)
                                        }
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(commentsService.isLoading)
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
                
                // Show approval section if identity exists but is not approved
                if let identityAddr = identityAddress, commentsService.isApproved != true {
                    Section {
                        Button(action: {
                            approveIdentity(identityAddress: identityAddr)
                        }) {
                            HStack {
                                if isApprovingIdentity {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .foregroundColor(.green)
                                }
                                Text(isApprovingIdentity ? "Approving..." : "Approve Identity")
                                    .foregroundColor(.green)
                                Spacer()
                                if !isApprovingIdentity {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(commentsService.isLoading || isApprovingIdentity)
                    } header: {
                        Text("Identity Approval")
                    } footer: {
                        Text("Approve your identity address to enable posting comments. This will send a transaction to the Ethereum Comments Protocol contract.")
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
        .alert("Approval Failed", isPresented: $showApprovalError) {
            Button("OK") {
                showApprovalError = false
            }
        } message: {
            Text(approvalError ?? "Failed to approve identity. Please try again.")
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
                    await commentsService.checkApproval(identityAddress: identityAddress, appAddress: ethereumAddress)
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
                    await commentsService.checkApproval(identityAddress: address, appAddress: ethereumAddress)
                }
            } else {
                print("No identity address found in storage.")
            }
        } catch {
            print("Failed to load identity address: \(error)")
        }
    }
    
    private func approveIdentity(identityAddress: String) {
        isApprovingIdentity = true
        let cbwallet = CoinbaseWalletSDK.shared
        
        do {
            // Create approval transaction data
            let expiry = Date().timeIntervalSince1970 + (100 * 365 * 24 * 60 * 60) // 100 years from now
            let transactionData = try commentsService.getApprovalTransactionData(
                appAddress: ethereumAddress,
                expiry: expiry
            )
            
            cbwallet.makeRequest(
                Request(
                    actions: [
                        Action(jsonRpc: .wallet_switchEthereumChain(chainId: "8453")),
                        Action(jsonRpc: .eth_sendTransaction(
                            fromAddress: identityAddress,
                            toAddress: "0xb262C9278fBcac384Ef59Fc49E24d800152E19b1",
                            weiValue: "0",
                            data: transactionData.hasPrefix("0x") ? transactionData : "0x" + transactionData,
                            nonce: nil,
                            gasPriceInWei: nil,
                            maxFeePerGas: nil,
                            maxPriorityFeePerGas: nil,
                            gasLimit: nil,
                            chainId: "8453",
                            actionSource: .none
                        ))
                    ], 
                    account: .init(chain: "base", networkId: 8453, address: identityAddress)
                )
            ) { result in
                DispatchQueue.main.async {
                    self.isApprovingIdentity = false
                    
                    switch result {
                    case .success(let response):
                        print("🎉 Identity approval transaction sent successfully")
                        print("Transaction hash: \(response)")
                        
                        // Check approval status after a delay to allow transaction to be mined
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            Task {
                                await self.commentsService.checkApproval(identityAddress: identityAddress, appAddress: self.ethereumAddress)
                            }
                        }
                        
                    case .failure(let error):
                        print("❌ Failed to send approval transaction: \(error)")
                        self.approvalError = error.localizedDescription
                        self.showApprovalError = true
                    }
                }
            }
            
        } catch {
            print("❌ Failed to create approval transaction data: \(error)")
            isApprovingIdentity = false
            approvalError = error.localizedDescription
            showApprovalError = true
        }
    }
}

struct ConnectWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var identityAddress: String?
    @State private var isConnecting = false
    @State private var selectedWallet: SupportedWallet = .coinbase
    @State private var connectionError: String?
    @State private var showErrorAlert = false
    @StateObject private var walletConfig = WalletConfigurationService.shared
    
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
                    
                    Text("Select your wallet and connect to verify your identity. This will allow you to sign messages and verify your Ethereum address.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Your Wallet")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(SupportedWallet.allCases, id: \.self) { wallet in
                            WalletOptionView(
                                wallet: wallet,
                                isSelected: selectedWallet == wallet,
                                action: {
                                    selectedWallet = wallet
                                    walletConfig.setSelectedWallet(wallet)
                                }
                            )
                        }
                    }
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
                                Image(systemName: selectedWallet.iconName)
                            }
                            Text(isConnecting ? "Connecting..." : walletConfig.needsAppRestart ? "Restart Required" : "Connect \(selectedWallet.displayName)")
                        }
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(walletConfig.needsAppRestart ? Color.orange : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isConnecting || walletConfig.needsAppRestart)
                    
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
        .onAppear {
            selectedWallet = walletConfig.selectedWallet
        }

        .alert("Connection Failed", isPresented: $showErrorAlert) {
            Button("OK") {
                showErrorAlert = false
            }
        } message: {
            Text(connectionError ?? "Failed to connect to wallet. Please try again.")
        }
    }
    
    private func connectWallet() {
        isConnecting = true
        
        // Establish connection with the selected wallet using CoinbaseWalletSDK
        let cbwallet = CoinbaseWalletSDK.shared
        
        cbwallet.initiateHandshake(
            initialActions: [
                Action(jsonRpc: .eth_requestAccounts)
            ]
        ) { result, account in
            DispatchQueue.main.async {
                
                switch result {
                case .success(let response):
                    print("🎉 Wallet connection successful")
                    print("Response: \(response)")
                    
                    guard let account = account else {
                        print("❌ No account returned from wallet")
                        isConnecting = false
                        return
                    }
                    
                    print("📱 Connected to \(selectedWallet.displayName)")
                    print("Account: \(account)")
                    
                    // Set the connected address as identity address
                    identityAddress = account.address
                    
                    // Persist the address
                    do {
                        try KeychainManager.storeIdentityAddress(account.address)
                        print("🔗 Persisted Wallet Address from \(selectedWallet.displayName): \(Utils.truncateAddress(account.address))")
                    } catch {
                        print("Failed to persist wallet address: \(error)")
                    }
                    
                    isConnecting = false
                    dismiss()
                    
                case .failure(let error):
                    print("❌ Wallet connection failed: \(error)")
                    connectionError = error.localizedDescription
                    showErrorAlert = true
                    isConnecting = false
                }
            }
        }
    }
}

// MARK: - Wallet Option View
struct WalletOptionView: View {
    let wallet: SupportedWallet
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: wallet.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.displayName)
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("MWP Compatible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
                        .onChange(of: addressInput) { _, newValue in
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
