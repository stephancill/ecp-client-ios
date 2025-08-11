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
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var notificationService: NotificationService
    @State private var privateKey: String = ""
    @State private var appAddress: String = ""
    @State private var isPrivateKeyVisible = false
    @State private var authorAddress: String? = nil
    @State private var showConnectWallet = false
    @State private var showEnterAddress = false
    @State private var isApprovingIdentity = false
    @State private var approvalError: String?
    @State private var showApprovalError = false
    @State private var isFundingAppAccount = false
    @State private var fundingError: String?
    @State private var showFundingError = false
    @StateObject private var balanceService = BalanceService()
    @StateObject private var commentsService = CommentsContractService()
    @StateObject private var authorProfileService = AuthorProfileService.shared
    @State private var authorProfile: AuthorProfile? = nil
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Identity"),
                    footer: Text("The Ethereum account you want to post as.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
                    if let address = authorAddress {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                AvatarView(
                                    address: address,
                                    size: 40,
                                    ensAvatarUrl: authorProfile?.ens?.avatarUrl,
                                    farcasterPfpUrl: authorProfile?.farcaster?.pfpUrl
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Connected Address")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text(Utils.truncateAddress(address))
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                }
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
                                            await commentsService.checkApproval(authorAddress: address, appAddress: appAddress)
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

                // Show approval section if author exists but is not approved
                if let authorAddr = authorAddress, commentsService.isApproved != true {
                    Section {
                        Button(action: {
                            approveAuthor(authorAddress: authorAddr)
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
                                Text(isApprovingIdentity ? "Approving..." : "Approve Author")
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
                        Text("Author Approval")
                    } footer: {
                        Text("Approve your author address to enable posting comments. This will send a transaction to the Ethereum Comments Protocol contract.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if authorAddress != nil {
                    Section {
                        Button(action: {
                            authorAddress = nil
                            // Remove from storage
                            do {
                                try KeychainManager.deleteIdentityAddress()
                            } catch {
                                // Handle error silently
                            }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Disconnect Author")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } header: {
                        Text("Author Management")
                    } footer: {
                        Text("Disconnect your author address to remove it from this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                
                
                if authorAddress == nil {
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
                        Text("Import your account from a wallet installed on this device.")
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
                        Text("Import your account from an unsupported wallet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(
                    header: Text("App Account"),
                    footer: Text("Your unique app account that submits posts to Base. Fund it with ETH on Base to cover gas fees.")
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
                                Text(Utils.truncateAddress(appAddress))
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
                                        await balanceService.fetchBalance(for: appAddress)
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
                            UIPasteboard.general.string = appAddress
                        }) {
                            Label("Copy Address", systemImage: "doc.on.doc")
                        }
                    }
                }
                
                // Fund App Account Section - Only show when wallet is connected
                if authorAddress != nil {
                    Section(
                        header: Text("Fund App Account"),
                        footer: Text("Send 0.00003 ETH to your app account to cover gas fees for posting comments.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    ) {
                        Button(action: {
                            fundAppAccount()
                        }) {
                            HStack {
                                if isFundingAppAccount {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "arrow.up.circle")
                                        .foregroundColor(.green)
                                }
                                Text(isFundingAppAccount ? "Sending..." : "Fund from wallet")
                                    .foregroundColor(.green)
                                Spacer()
                                if !isFundingAppAccount {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(isFundingAppAccount)
                    }
                }

                // Debug & Notifications Section
                Section(
                    header: Text("Debug")
                ) {
                    NavigationLink(destination: DebugView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.orange)
                            Text("Debug Tools")
                            Spacer()
                        }
                    }
                    NavigationLink(destination: NotificationsView()) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                            Text("Notifications")
                            Spacer()
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
            ConnectWalletView(authorAddress: $authorAddress, appAddress: appAddress, commentsService: commentsService)
        }
        .sheet(isPresented: $showEnterAddress) {
            EnterAddressView(authorAddress: $authorAddress, appAddress: appAddress, commentsService: commentsService)
        }
        // Trigger backend approvals sync whenever local approval status changes
        .onChange(of: commentsService.isApproved) { _, newValue in
            guard let _ = newValue else { return }
            Task { @MainActor in
                // Only attempt if authenticated
                if authService.isAuthenticated {
                    let api = APIService(authService: authService)
                    do { _ = try await api.syncApprovals(chainId: 8453) } catch { }
                }
            }
        }
        .alert("Approval Failed", isPresented: $showApprovalError) {
            Button("OK") {
                showApprovalError = false
            }
        } message: {
            Text(approvalError ?? "Failed to approve identity. Please try again.")
        }
        .alert("Funding Failed", isPresented: $showFundingError) {
            Button("OK") {
                showFundingError = false
            }
        } message: {
            Text(fundingError ?? "Failed to send ETH to app account. Please try again.")
        }
        .onAppear {
            loadPrivateKey()
            loadAuthorAddress()
            Task { await fetchProfileIfNeeded() }
        }
        .onChange(of: authorAddress) { _, _ in
            Task { await fetchProfileIfNeeded() }
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
            appAddress = ethereumPrivateKey.address.hex(eip55: true)
            
            // Fetch balance for the derived address
            Task {
                await balanceService.fetchBalance(for: appAddress)
            }
            
            // Check approval now that app address is ready
            checkApprovalIfReady()
        } catch {
            appAddress = "" // Set to empty instead of error message
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
            // Handle error silently
        }
    }
    
    private func loadAuthorAddress() {
        do {
            authorAddress = try KeychainManager.retrieveIdentityAddress()
            if let address = authorAddress {
                // Check approval status when author is loaded
                checkApprovalIfReady()
                Task { await fetchProfileIfNeeded() }
            }
        } catch {
            // Handle error silently
        }
    }
    
    private func checkApprovalIfReady() {
        guard let authorAddr = authorAddress, !appAddress.isEmpty else {
            return
        }
        
        // Validate address formats before making the call
        let addressPattern = "^0x[a-fA-F0-9]{40}$"
        let authorValid = authorAddr.range(of: addressPattern, options: .regularExpression) != nil
        let appValid = appAddress.range(of: addressPattern, options: .regularExpression) != nil
        
        guard authorValid && appValid else {
            return
        }
        
        Task {
            await commentsService.checkApproval(authorAddress: authorAddr, appAddress: appAddress)
        }
    }
    
    private func fetchProfileIfNeeded() async {
        guard let addr = authorAddress else { return }
        do {
            let profile = try await authorProfileService.fetch(address: addr)
            await MainActor.run { self.authorProfile = profile }
        } catch {
            // ignore errors
        }
    }
    
    private func approveAuthor(authorAddress: String) {
        isApprovingIdentity = true
        let cbwallet = CoinbaseWalletSDK.shared
        
        do {
            // Create approval transaction data
            let expiry = Date().timeIntervalSince1970 + (100 * 365 * 24 * 60 * 60) // 100 years from now
            let transactionData = try commentsService.getApprovalTransactionData(
                appAddress: appAddress,
                expiry: expiry
            )
            
            cbwallet.makeRequest(
                Request(
                    actions: [
                        Action(jsonRpc: .wallet_switchEthereumChain(chainId: "8453")),
                        Action(jsonRpc: .eth_sendTransaction(
                            fromAddress: authorAddress,
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
                    account: .init(chain: "base", networkId: 8453, address: authorAddress)
                )
            ) { result in
                DispatchQueue.main.async {
                    self.isApprovingIdentity = false
                    
                    switch result {
                    case .success(let response):
                        // Check approval status after a delay to allow transaction to be mined
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            Task {
                                await self.commentsService.checkApproval(authorAddress: authorAddress, appAddress: self.appAddress)
                            }
                        }
                        
                    case .failure(let error):
                        self.approvalError = error.localizedDescription
                        self.showApprovalError = true
                    }
                }
            }
            
        } catch {
            isApprovingIdentity = false
            approvalError = error.localizedDescription
            showApprovalError = true
        }
    }
    
    private func fundAppAccount() {
        guard let authorAddr = authorAddress else { return }
        
        isFundingAppAccount = true
        let cbwallet = CoinbaseWalletSDK.shared
        
        // Convert 0.00003 ETH to wei (1 ETH = 10^18 wei)
        let ethAmount = "0.00003"
        let weiAmount = String(format: "%.0f", Double(ethAmount)! * 1e18)
        
        cbwallet.makeRequest(
            Request(
                actions: [
                    Action(jsonRpc: .wallet_switchEthereumChain(chainId: "8453")),
                    Action(jsonRpc: .eth_sendTransaction(
                        fromAddress: authorAddr,
                        toAddress: appAddress,
                        weiValue: weiAmount,
                        data: "0x",
                        nonce: nil,
                        gasPriceInWei: nil,
                        maxFeePerGas: nil,
                        maxPriorityFeePerGas: nil,
                        gasLimit: nil,
                        chainId: "8453",
                        actionSource: .none
                    ))
                ], 
                account: .init(chain: "base", networkId: 8453, address: authorAddr)
            )
        ) { result in
            DispatchQueue.main.async {
                self.isFundingAppAccount = false
                
                switch result {
                case .success(let response):
                    // Refresh balance after a delay to allow transaction to be mined
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        Task {
                            await self.balanceService.fetchBalance(for: self.appAddress)
                        }
                    }
                    
                case .failure(let error):
                    self.fundingError = error.localizedDescription
                    self.showFundingError = true
                }
            }
        }
    }
}

struct ConnectWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var authorAddress: String?
    let appAddress: String
    let commentsService: CommentsContractService
    @State private var isConnecting = false
    @State private var selectedWallet: SupportedWallet = .coinbase
    @State private var connectionError: String?
    @State private var showErrorAlert = false
    @State private var showRestartAlert = false
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
                        if walletConfig.needsAppRestart {
                            showRestartAlert = true
                        } else {
                            connectWallet()
                        }
                    }) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: selectedWallet.iconName)
                            }
                            Text(isConnecting ? "Connecting..." : walletConfig.needsAppRestart ? "App Restart Required" : "Connect \(selectedWallet.displayName)")
                        }
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(walletConfig.needsAppRestart ? Color.orange : Color.blue)
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
        .alert("App Restart Required", isPresented: $showRestartAlert) {
            Button("Restart App") {
                // Force quit the app
                exit(0)
            }
            Button("Cancel", role: .cancel) {
                showRestartAlert = false
            }
        } message: {
            Text("The wallet configuration has changed and requires an app restart to take effect.")
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
                    guard let account = account else {
                        isConnecting = false
                        return
                    }
                    
                    // Set the connected address as author address
                    authorAddress = account.address
                    
                    // Persist the address
                    do {
                        try KeychainManager.storeIdentityAddress(account.address)
                    } catch {
                        // Handle error silently
                    }
                    
                    // Check approval status immediately after wallet connection
                    if !appAddress.isEmpty {
                        Task {
                            await commentsService.checkApproval(authorAddress: account.address, appAddress: appAddress)
                        }
                    }
                    
                    isConnecting = false
                    dismiss()
                    
                case .failure(let error):
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
    @Binding var authorAddress: String?
    let appAddress: String
    let commentsService: CommentsContractService
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
                            authorAddress = addressInput
                            persistAuthorAddress(addressInput)
                            
                            // Check approval status immediately after manual address entry
                            if !appAddress.isEmpty {
                                Task {
                                    await commentsService.checkApproval(authorAddress: addressInput, appAddress: appAddress)
                                }
                            }
                            
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
    
    private func persistAuthorAddress(_ address: String) {
        do {
            try KeychainManager.storeIdentityAddress(address)
        } catch {
            // Handle error silently
        }
    }
}

#Preview("Settings") {
    let authService = AuthService()
    let notificationService = NotificationService(authService: authService)
    return SettingsView()
        .environmentObject(authService)
        .environmentObject(notificationService)
} 
