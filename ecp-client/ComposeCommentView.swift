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
import PhotosUI

// MARK: - Constants
private let maxImages = 5

struct ComposeCommentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @StateObject private var commentsService = CommentsContractService()
    @StateObject private var pollingService = CommentPollingService()
    @StateObject private var balanceService = BalanceService()
    @StateObject private var imageUploadService = ImageUploadService()
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
                    loadingView
                } else if !identityService.isIdentityConfigured {
                    configurationRequiredView  
                } else {
                    // Identity configured - show normal compose interface
                    
                    // Reply context (if replying to a comment)
                    if let parentComment = parentComment {
                        replyContextView(for: parentComment)
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
                    
                    // Image Selection - Grid for 3 or fewer, Carousel for more
                    if !selectedImages.isEmpty {
                        if selectedImages.count <= 3 {
                            // Grid layout for 3 or fewer images
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    imageView(for: image, at: index)
                                }
                            }
                        } else {
                            // Horizontal carousel for more than 3 images
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        imageView(for: image, at: index)
                                            .frame(width: 120, height: 120)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    
                    // Image Upload Progress
                    if imageUploadService.isUploading {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(selectedImages.count > 1 ? "Uploading images..." : "Uploading image...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(imageUploadService.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: imageUploadService.uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
                    
                    // Character Count and Image Upload
                    HStack {
                        // Image Picker Button
                        PhotosPicker(selection: $selectedPhotos, matching: .images) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.gray)
                            .padding(.vertical, 6)
                            
                        }
                        .disabled(imageUploadService.isUploading || selectedImages.count >= maxImages)
                        
                         Spacer()
                        
                         // Character Count
                         Text("\(commentText.count)/500")
                             .font(.caption)
                             .foregroundColor(commentText.count > 500 ? .red : .secondary)
                    }
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
                
                // Image upload error
                if let uploadError = imageUploadService.uploadError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(uploadError)
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
        .onChange(of: selectedPhotos) { newPhotos in
            Task {
                // Clear existing images first
                await MainActor.run {
                    selectedImages.removeAll()
                }
                
                // Process new photos (limit to maxImages)
                let photosToProcess = Array(newPhotos.prefix(maxImages))
                
                for photo in photosToProcess {
                    do {
                        if let data = try await photo.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    if selectedImages.count < maxImages {
                                        selectedImages.append(uiImage)
                                    }
                                }
                            }
                        }
                    } catch {
                        await MainActor.run {
                            imageUploadService.uploadError = "Failed to load one or more images"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Computed Views
extension ComposeCommentView {
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Checking configuration...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var configurationRequiredView: some View {
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
    }
    
    private func replyContextView(for parentComment: Comment) -> some View {
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
}

extension ComposeCommentView {
    private func channelIdForCurrentContext() -> BigUInt {
        if let parentComment = parentComment {
            let raw = parentComment.channelId.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.lowercased().hasPrefix("0x") {
                if let parsed = BigUInt(raw.dropFirst(2), radix: 16) { return parsed }
            } else if let parsed = BigUInt(raw, radix: 10) {
                return parsed
            }
        }
        return CommentParams.defaultChannelId
    }
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
                channelId: channelIdForCurrentContext(),
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
        imageUploadService.uploadError = nil
        
        Task {
            do {
                // Upload images if any are selected
                var finalCommentText = commentText
                if !selectedImages.isEmpty {
                    do {
                        var imageURLs: [String] = []
                        for image in selectedImages {
                            let imageURL = try await imageUploadService.uploadImage(image)
                            imageURLs.append(imageURL)
                        }
                        // Append all image URLs to the comment text
                        finalCommentText = commentText + " " + imageURLs.joined(separator: " ")
                    } catch {
                        await MainActor.run {
                            imageUploadService.uploadError = error.localizedDescription
                            isPosting = false
                        }
                        return
                    }
                }
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
                    channelId: channelIdForCurrentContext(),
                    content: finalCommentText,
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
    
    // MARK: - Helper Views
    @ViewBuilder
    private func imageView(for image: UIImage, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            
            // Delete button overlay
            Button(action: {
                selectedImages.remove(at: index)
                if index < selectedPhotos.count {
                    selectedPhotos.remove(at: index)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(6)
        }
    }
}


#Preview {
    ComposeCommentView(identityService: IdentityService(), parentComment: nil)
} 
