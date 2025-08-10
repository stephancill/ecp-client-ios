//
//  ComposeCommentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3
import CachedAsyncImage
import BigInt

struct ComposeCommentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @StateObject private var commentsService = CommentsContractService()
    @StateObject private var pollingService = CommentPollingService()
    @StateObject private var balanceService = BalanceService()
    @State private var hasSufficientBalance: Bool = true
    @State private var identityAddress: String? = nil
    @State private var authorProfile: AuthorProfile? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    let identityService: IdentityService
    let parentComment: Comment?
    var onCommentPosted: (() -> Void)?
    
    init(identityService: IdentityService, parentComment: Comment? = nil, onCommentPosted: (() -> Void)? = nil) {
        self.identityService = identityService
        self.parentComment = parentComment
        self.onCommentPosted = onCommentPosted
        // Seed identity address synchronously to avoid placeholder flash
        if let addr = try? KeychainManager.retrieveIdentityAddress() {
            self._identityAddress = State(initialValue: addr)
            if let cached = AuthorProfileService.shared.cachedProfile(for: addr) {
                self._authorProfile = State(initialValue: cached)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if identityService.isIdentityConfigured {
                    // Insufficient funds banner
                    if !hasSufficientBalance {
                        InfoBannerView(
                            iconSystemName: "creditcard.trianglebadge.exclamation",
                            iconBackgroundColor: .orange.opacity(0.15),
                            iconForegroundColor: .orange,
                            title: "Insufficient funds",
                            subtitle: "Fund your app account to post."
                                + (balanceService.balance.isEmpty ? "" : " Balance: \(balanceService.balance)"),
                            buttonTitle: "Fund",
                            buttonAction: { showingSettings = true }
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.orange.opacity(0.08))
                        )
                    }
                }
                if identityService.isCheckingIdentity {
                    // Loading state while checking configuration
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Checking configuration...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if !identityService.isIdentityConfigured {
                    // No identity configured - show message and settings button
                    VStack(spacing: 20) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("Configure identity and approval to post")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("You need to configure your identity address and get approval in settings before you can post comments.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Open Settings")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                } else {
                    // Identity configured - show normal compose interface
                    
                    // Reply context (if replying to a comment)
                    if let parentComment = parentComment {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("Replying to")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                // Parent comment avatar (unified)
                                AvatarView(
                                    address: parentComment.author.address,
                                    size: 24,
                                    ensAvatarUrl: parentComment.author.ens?.avatarUrl,
                                    farcasterPfpUrl: parentComment.author.farcaster?.pfpUrl
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    // Author name (unified)
                                    Text(
                                        Utils.displayName(
                                            ensName: parentComment.author.ens?.name,
                                            farcasterUsername: parentComment.author.farcaster?.username,
                                            fallbackAddress: parentComment.author.address
                                        )
                                    )
                                    .font(.caption)
                                    .fontWeight(.medium)

                                    // Parent comment content (truncated)
                                    Text(parentComment.content)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                    
                    // Text Editor with Avatar
                    HStack(alignment: .top, spacing: 12) {
                        if let addr = identityAddress {
                            // Prefer cached/fetched profile; if none yet, show neutral placeholder to avoid blockies flash
                            let cached = AuthorProfileService.shared.cachedProfile(for: addr)
                            if let profile = (authorProfile ?? cached) {
                                AvatarView(
                                    address: addr,
                                    size: 40,
                                    ensAvatarUrl: profile.ens?.avatarUrl,
                                    farcasterPfpUrl: profile.farcaster?.pfpUrl
                                )
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // Text Editor
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $commentText)
                                .font(.body)
                                .frame(minHeight: 80)
                            
                            if commentText.isEmpty {
                                Text(parentComment != nil ? "Write your reply..." : "What's your take?")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                
                // Character Count
                HStack {
                    Spacer()
                    Text("\(commentText.count)/500")
                        .font(.caption)
                        .foregroundColor(commentText.count > 500 ? .red : .secondary)
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Polling Status
                if pollingService.isPolling {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Waiting for comment to appear...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Polling Error
                if let pollingError = pollingService.pollingError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(pollingError)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle(parentComment != nil ? "Reply" : "New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(pollingService.isPolling ? "Dismiss" : "Cancel") {
                        if pollingService.isPolling {
                            pollingService.stopPolling()
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if identityService.isIdentityConfigured {
                        Button("Post") {
                            postComment()
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting || pollingService.isPolling || !hasSufficientBalance)
                        .opacity(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting || pollingService.isPolling || !hasSufficientBalance ? 0.6 : 1.0)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Re-check identity configuration when settings sheet is dismissed
            Task {
                await identityService.checkIdentityConfiguration()
                await checkFunds()
                await loadIdentityAndProfile()
            }
        }) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            // Stop polling when view is dismissed
            pollingService.stopPolling()
        }
        .onAppear {
            Task {
                await checkFunds()
                await loadIdentityAndProfile()
                // If identity already known, warm profile + image cache
                if let addr = try? KeychainManager.retrieveIdentityAddress(),
                   AuthorProfileService.shared.cachedProfile(for: addr) == nil {
                    Task.detached { [addr] in _ = try? await AuthorProfileService.shared.fetch(address: addr) }
                }
            }
        }
    }
}

extension ComposeCommentView {
    private func loadIdentityAndProfile() async {
        do {
            if let addr = try KeychainManager.retrieveIdentityAddress() {
                await MainActor.run { self.identityAddress = addr }
                do {
                    let profile = try await AuthorProfileService.shared.fetch(address: addr)
                    await MainActor.run { self.authorProfile = profile }
                } catch {
                    // Ignore profile errors, keep fallback avatar
                }
            } else {
                await MainActor.run { self.identityAddress = nil; self.authorProfile = nil }
            }
        } catch {
            await MainActor.run { self.identityAddress = nil; self.authorProfile = nil }
        }
    }
    private func checkFunds() async {
        guard identityService.isIdentityConfigured else { return }
        do {
            // Retrieve keys and derive app address
            guard let identityAddress = try KeychainManager.retrieveIdentityAddress() else { return }
            let privateKey = try KeychainManager.retrievePrivateKey()
            let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
            let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
            let appAddress = ethereumPrivateKey.address.hex(eip55: true)

            // Build params with minimal content; gas does not depend on text size materially, but use current text
            let parentId: Data? = parentComment != nil ? Data(hex: parentComment!.id) : nil
            let params = CommentParams(
                identityAddress: identityAddress,
                appAddress: appAddress,
                channelId: 0,
                content: commentText.isEmpty ? "." : commentText,
                targetUri: "",
                parentId: parentId
            )

            // Estimate post cost
            let result = try await commentsService.estimatePostCost(params: params, fromPrivateKey: privateKey)

            // Fetch balance and compare
            await balanceService.fetchBalance(for: appAddress)
            hasSufficientBalance = isBalanceSufficient(balanceText: balanceService.balance, requiredWei: result.totalCost)
        } catch {
            // If estimation fails, keep post enabled; only disable when we know it's insufficient
            print("⚠️ Failed to estimate post cost: \(error)")
        }
    }

    private func isBalanceSufficient(balanceText: String, requiredWei: BigUInt) -> Bool {
        guard let weiBalance = ethStringToWei(balanceText) else { return true }
        return weiBalance >= requiredWei
    }

    private func ethStringToWei(_ text: String) -> BigUInt? {
        // Expect formats like "0.123456 ETH" or "0.123456"
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasSuffix(" ETH") {
            cleaned = String(cleaned.dropLast(4))
        }
        guard let decimal = Decimal(string: cleaned) else { return nil }
        let weiPerEth = Decimal(string: "1000000000000000000")! // 1e18
        let weiDecimal = decimal * weiPerEth
        // Round down to integer wei
        var result = NSDecimalNumber(decimal: weiDecimal)
        let handler = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        result = result.rounding(accordingToBehavior: handler)
        return BigUInt(result.stringValue, radix: 10)
    }
    private func postComment() {
        isPosting = true
        errorMessage = nil
        
        Task {
            do {
                // Retrieve stored data from keychain
                guard let identityAddress = try KeychainManager.retrieveIdentityAddress() else {
                    throw KeychainManager.KeychainError.itemNotFound
                }
                let privateKey = try KeychainManager.retrievePrivateKey()
                
                // Derive app address from private key
                let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
                let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
                let appAddress = ethereumPrivateKey.address.hex(eip55: true)
                
                // Create comment parameters once to ensure consistency between getCommentId and postComment
                let parentId: Data? = parentComment != nil ? Data(hex: parentComment!.id) : nil
                let commentParams = CommentParams(
                    identityAddress: identityAddress,
                    appAddress: appAddress,
                    channelId: 0,
                    content: commentText,
                    targetUri: "",
                    parentId: parentId
                )
                
                // First, get the comment ID using the same parameters
                let commentId = try await commentsService.getCommentId(params: commentParams)
                
                // Convert comment ID hex string to Data for signing
                let commentIdData = Data(hex: commentId)
                
                // Sign the comment ID (convert Data to Array<UInt8>)
                let signatureTuple = try ethereumPrivateKey.sign(hash: Array(commentIdData))
                
                // Convert to compact signature format (64-byte)
                let compactSignature = Utils.toCompactSignature(signatureTuple)
                // Convert to canonical signature format (65-byte) for external utilities
                let canonicalSignature = Utils.toCanonicalSignature(signatureTuple)
                
                // Post the comment using the same parameters to ensure consistent comment ID
                let txHash = try await commentsService.postComment(
                    params: commentParams,
                    appSignature: canonicalSignature,
                    privateKey: privateKey
                )
                
                // Start polling for the comment to appear in the feed
                await MainActor.run {
                    isPosting = false
                    // Don't dismiss yet, show polling status
                }
                
                // Start polling for the comment
                pollingService.startPolling(
                    commentId: commentId,
                    onSuccess: {
                        // Comment found! Refresh feed first, then dismiss
                        onCommentPosted?()
                        // Small delay to ensure refresh starts before dismissing
                        Task {
                            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000)) // 100ms
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    },
                    onTimeout: {
                        // Polling timed out, still refresh feed in case comment appeared
                        onCommentPosted?()
                        // Give user a moment to see the error message, then dismiss
                        Task {
                            try await Task.sleep(nanoseconds: UInt64(3 * 1_000_000_000)) // 3 seconds
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                )
                
            } catch KeychainManager.KeychainError.itemNotFound {
                await MainActor.run {
                    errorMessage = "Please configure your identity address and get approval in settings first"
                    isPosting = false
                }
            } catch {
                print("❌ Failed to post comment: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to post comment: \(error.localizedDescription)"
                    isPosting = false
                }
            }
        }
    }
}


#Preview {
    ComposeCommentView(identityService: IdentityService(), parentComment: nil)
} 
