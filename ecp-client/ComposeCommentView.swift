//
//  ComposeCommentView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import Web3
import BigInt
import CachedAsyncImage

struct ComposeCommentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @StateObject private var commentsService = CommentsContractService()
    @StateObject private var pollingService = CommentPollingService()
    @StateObject private var channelManagerService = ChannelManagerService()
    @State private var selectedChannelIndex: Int = 0
    @State private var estimatedRequiredWei: BigUInt? = nil
    @State private var estimatedBalanceWei: BigUInt? = nil
    @State private var isEstimating = false
    
    let identityService: IdentityService
    let parentComment: Comment?
    var onCommentPosted: (() -> Void)?
    @ObservedObject var channelsService: ChannelsService
    
    init(identityService: IdentityService, parentComment: Comment? = nil, onCommentPosted: (() -> Void)? = nil, channelsService: ChannelsService) {
        self.identityService = identityService
        self.parentComment = parentComment
        self.onCommentPosted = onCommentPosted
        self._channelsService = ObservedObject(wrappedValue: channelsService)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
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
                    
                    // Channel Picker (top-level posts only)
                    if parentComment == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Channel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Channel", selection: $selectedChannelIndex) {
                                ForEach(Array(channelsService.channels.enumerated()), id: \.offset) { index, channel in
                                    Text(channel.name)
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedChannelIndex) { _, newIndex in
                                print("🔎 [Compose] channel selection changed to index=\(newIndex), id=\(selectedChannelIdString() ?? "nil")")
            Task { await loadFeeForSelectedChannel() }
            Task { await debounceAndEstimate() }
                            }
                            // Fee row
                            HStack(spacing: 6) {
                                if channelManagerService.isLoadingFee {
                                    ProgressView().scaleEffect(0.8)
                                }
                                if let fee = selectedFeeFromCache() {
                                    Text("Fee: \(channelManagerService.formatWeiToEthString(fee))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Fee: —")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let req = estimatedRequiredWei, let bal = estimatedBalanceWei {
                                let needs = req > bal
                                HStack(spacing: 6) {
                                    if isEstimating { ProgressView().scaleEffect(0.7) }
                                    Text(needs ? "Insufficient funds for gas+fee" : "Sufficient balance")
                                        .font(.caption)
                                        .foregroundColor(needs ? .orange : .secondary)
                                    if needs {
                                        Button {
                                            print("🔎 [Compose] CTA to open Settings")
                                            showingSettings = true
                                        } label: {
                                            Text("Open Settings")
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }

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
                                // Parent comment avatar
                                if let farcaster = parentComment.author.farcaster {
                                    CachedAsyncImage(url: URL(string: farcaster.pfpUrl ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        BlockiesAvatarView(address: parentComment.author.address, size: 24)
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                } else {
                                    BlockiesAvatarView(address: parentComment.author.address, size: 24)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    // Author name
                                    if let farcaster = parentComment.author.farcaster {
                                        Text("@\(farcaster.username)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    } else if let ens = parentComment.author.ens {
                                        Text(ens.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    } else {
                                        Text(Utils.truncateAddress(parentComment.author.address))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    
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
                        // Placeholder Avatar
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                        
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
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting || pollingService.isPolling)
                        .opacity(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentText.count > 500 || isPosting || pollingService.isPolling ? 0.6 : 1.0)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            // Re-check identity configuration when settings sheet is dismissed
            Task {
                await identityService.checkIdentityConfiguration()
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
            // Default selected channel index to first available
            if parentComment == nil, selectedChannelIndex >= channelsService.channels.count {
                selectedChannelIndex = 0
            }
            if parentComment == nil, channelsService.channels.indices.contains(selectedChannelIndex) {
                print("🔎 [Compose] onAppear trigger fee load for id=\(selectedChannelIdString() ?? "nil")")
                Task { await loadFeeForSelectedChannel() }
                Task { await debounceAndEstimate() }
            }
        }
        .onChange(of: channelsService.channels.map { $0.id }.joined(separator: ",")) { _, _ in
            if parentComment == nil, channelsService.channels.indices.contains(selectedChannelIndex) {
                print("🔎 [Compose] channels list changed, reloading fee for id=\(selectedChannelIdString() ?? "nil")")
                Task { await loadFeeForSelectedChannel() }
                Task { await debounceAndEstimate() }
            }
        }
    }
}

extension ComposeCommentView {
    private func selectedChannelIdBigUInt() -> BigUInt? {
        guard parentComment == nil, channelsService.channels.indices.contains(selectedChannelIndex) else { return nil }
        let raw = channelsService.channels[selectedChannelIndex].id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("0x") {
            let hexPart = String(raw.dropFirst(2))
            return BigUInt(hexPart, radix: 16)
        } else {
            return BigUInt(raw, radix: 10)
        }
    }
    private func selectedChannelIdUInt64() -> UInt64? {
        guard parentComment == nil, channelsService.channels.indices.contains(selectedChannelIndex) else { return nil }
        let channel = channelsService.channels[selectedChannelIndex]
        let raw = channel.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("0x") {
            let hexPart = String(raw.dropFirst(2))
            if let value = UInt64(hexPart, radix: 16) { return value }
        } else {
            if let value = UInt64(raw, radix: 10) { return value }
        }
        return nil
    }

    private func selectedChannelIdString() -> String? {
        guard parentComment == nil, channelsService.channels.indices.contains(selectedChannelIndex) else { return nil }
        return channelsService.channels[selectedChannelIndex].id
    }

    private func loadFeeForSelectedChannel() async {
        // Try numeric id first
        if let channelId = selectedChannelIdUInt64() {
            // If UI already has a hook address cached for this channel, pass it to avoid tuple decoding flakiness
            let hook = channelsService.channels[channelsService.channels.indices.contains(selectedChannelIndex) ? selectedChannelIndex : 0].hook
            await channelManagerService.loadPostFeeWei(for: channelId, hookAddress: hook)
        } else if let idString = selectedChannelIdString() {
            let hook = channelsService.channels[channelsService.channels.indices.contains(selectedChannelIndex) ? selectedChannelIndex : 0].hook
            await channelManagerService.loadPostFeeWei(channelIdString: idString, hookAddress: hook)
        }
    }

    private func selectedFeeFromCache() -> BigUInt? {
        // Prefer numeric cache, fallback to string cache
        if let id = selectedChannelIdUInt64(), let fee = channelManagerService.feeWei(for: id) { return fee }
        if let idStr = selectedChannelIdString(), let fee = channelManagerService.feeWei(forChannelIdString: idStr) { return fee }
        return nil
    }

    @MainActor
    private func debounceAndEstimate() async {
        isEstimating = true
        // Simple debounce: wait 250ms, last call wins
        try? await Task.sleep(nanoseconds: 250_000_000)

        do {
            // Gather inputs
            guard let identityAddress = try KeychainManager.retrieveIdentityAddress() else {
                isEstimating = false
                return
            }
            let privateKey = try KeychainManager.retrievePrivateKey()

            // Derive app address from the stored private key
            let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
            let ethKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
            let appAddress = ethKey.address.hex(eip55: true)

            // Build params with the actual app address
            let parentId: Data? = parentComment != nil ? Data(hex: parentComment!.id) : nil
            let params = CommentParams(
                identityAddress: identityAddress,
                appAddress: appAddress,
                channelId: selectedChannelIdBigUInt() ?? 0,
                content: commentText,
                targetUri: "",
                parentId: parentId
            )

            // Resolve fee; if not cached yet, fetch and then read from cache
            var fee = selectedFeeFromCache()
            if fee == nil {
                if let idStr = selectedChannelIdString() {
                    let hook = channelsService.channels[channelsService.channels.indices.contains(selectedChannelIndex) ? selectedChannelIndex : 0].hook
                    print("🔎 [Compose] fee not cached; loading for string id=\(idStr)")
                    await channelManagerService.loadPostFeeWei(channelIdString: idStr, hookAddress: hook)
                    fee = selectedFeeFromCache()
                }
            }
            let feeValue = fee ?? 0
            print("🔎 [Compose] estimation using app=\(appAddress) fee=\(feeValue)")

            if let estimate = await commentsService.estimatePostCost(
                params: params,
                appSignature: nil,
                privateKey: privateKey,
                valueWei: feeValue
            ) {
                estimatedRequiredWei = estimate.requiredWei
                estimatedBalanceWei = estimate.balanceWei
                print("🔎 [Compose] estimate requiredWei=\(estimate.requiredWei) gasPrice=\(estimate.gasPrice.quantity) gasLimit=\(estimate.gasLimit.quantity) balanceWei=\(estimate.balanceWei)")
            }
        } catch {
            print("❌ [Compose] estimation failed: \(error)")
        }
        isEstimating = false
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
                    channelId: selectedChannelIdBigUInt() ?? 0,
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
                
                // Resolve fee to attach (supports numeric and 256-bit string ids)
                let feeToAttach = selectedChannelIdUInt64().flatMap { channelManagerService.feeWei(for: $0) }
                    ?? selectedChannelIdString().flatMap { channelManagerService.feeWei(forChannelIdString: $0) }
                let feeBuffered = feeToAttach.map { $0 + 1 } // add 1 wei safety buffer
                print("🔎 [Compose] feeToAttach=\(String(describing: feeToAttach)) buffered=\(String(describing: feeBuffered))")

                // Post the comment using the same parameters to ensure consistent comment ID
                let txHash = try await commentsService.postComment(
                    params: commentParams,
                    appSignature: canonicalSignature,
                    privateKey: privateKey,
                    valueWei: feeBuffered
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
    ComposeCommentView(identityService: IdentityService(), parentComment: nil, channelsService: ChannelsService())
} 
