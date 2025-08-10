//
//  CommentManager.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation
import BigInt
#if !Web3CocoaPods
    import Web3
#endif
import Web3ContractABI

/// Parameters for creating a comment
public struct CommentParams {
    public let identityAddress: String
    public let appAddress: String
    public let channelId: BigUInt
    public let content: String
    public let targetUri: String
    public let deadline: TimeInterval
    public let parentId: Data?
    public let metadata: [MetadataEntry]
    
    public init(
        identityAddress: String,
        appAddress: String,
        channelId: BigUInt = 0,
        content: String,
        targetUri: String = "",
        deadline: TimeInterval? = nil,
        parentId: Data? = nil,
        metadata: [MetadataEntry] = []
    ) {
        self.identityAddress = identityAddress
        self.appAddress = appAddress
        self.channelId = channelId
        self.content = content
        self.targetUri = targetUri
        self.deadline = deadline ?? (Date().timeIntervalSince1970 + 3600) // Default to 1 hour from now
        self.parentId = parentId
        self.metadata = metadata
    }
}

/// Metadata entry structure for comments
public struct MetadataEntry {
    public let key: Data // bytes32
    public let value: Data // bytes
    
    public init(key: Data, value: Data) {
        self.key = key
        self.value = value
    }
}

/// Comment data structure for creating comments
public struct CreateComment {
    public let author: EthereumAddress
    public let app: EthereumAddress
    public let channelId: BigUInt
    public let deadline: BigUInt
    public let parentId: Data // bytes32
    public let commentType: UInt8
    public let content: String
    public let metadata: [MetadataEntry]
    public let targetUri: String
    
    public init(author: EthereumAddress, app: EthereumAddress, channelId: BigUInt, deadline: BigUInt, parentId: Data, commentType: UInt8, content: String, metadata: [MetadataEntry], targetUri: String) {
        self.author = author
        self.app = app
        self.channelId = channelId
        self.deadline = deadline
        self.parentId = parentId
        self.commentType = commentType
        self.content = content
        self.metadata = metadata
        self.targetUri = targetUri
    }
}

/// Base protocol for Comments Contract
public protocol CommentsContract: EthereumContract {
    func isApproved(identityAddress: EthereumAddress, app: EthereumAddress) -> SolidityInvocation
    func postCommentWithSig(commentData: CreateComment, authorSignature: Data, appSignature: Data) -> SolidityInvocation
    func getCommentId(commentData: CreateComment) -> SolidityInvocation
    func getDeleteCommentHash(commentId: Data, author: EthereumAddress, app: EthereumAddress, deadline: BigUInt) -> SolidityInvocation
    func deleteCommentWithSig(commentId: Data, app: EthereumAddress, deadline: BigUInt, authorSignature: Data, appSignature: Data) -> SolidityInvocation
    func addApproval(app: EthereumAddress, expiry: BigUInt) -> SolidityInvocation
}

/// Generic implementation class for Comments contract
open class GenericCommentsContract: StaticContract, CommentsContract {
    public var address: EthereumAddress?
    public let eth: Web3.Eth
    
    open var constructor: SolidityConstructor?
    
    open var events: [SolidityEvent] {
        return [] // Add events if needed
    }
    
    public required init(address: EthereumAddress?, eth: Web3.Eth) {
        self.address = address
        self.eth = eth
    }
}

// MARK: - Implementation of Comments contract methods

public extension CommentsContract {
    
    func isApproved(identityAddress: EthereumAddress, app: EthereumAddress) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "author", type: .address),
            SolidityFunctionParameter(name: "app", type: .address)
        ]
        let outputs = [
            SolidityFunctionParameter(name: "", type: .bool)
        ]
        let method = SolidityConstantFunction(name: "isApproved", inputs: inputs, outputs: outputs, handler: self)
        return method.invoke(identityAddress, app)
    }
    
    func postCommentWithSig(commentData: CreateComment, authorSignature: Data, appSignature: Data) -> SolidityInvocation {
        // Define the MetadataEntry tuple type
        let metadataEntryType = SolidityType.tuple([
            SolidityType.bytes(length: 32), // key
            SolidityType.bytes(length: nil)    // value
        ])
        
        // Define the CreateComment tuple type
        let createCommentType = SolidityType.tuple([
            SolidityType.address,     // author
            SolidityType.address,     // app
            SolidityType.uint256,     // channelId
            SolidityType.uint256,     // deadline
            SolidityType.bytes(length: 32),     // parentId
            SolidityType.uint8,       // commentType
            SolidityType.string,      // content
            SolidityType.array(type: metadataEntryType, length: nil),
            SolidityType.string       // targetUri
        ])
        
        let inputs = [
            SolidityFunctionParameter(name: "commentData", type: createCommentType),
            SolidityFunctionParameter(name: "authorSignature", type: .bytes(length: nil)),
            SolidityFunctionParameter(name: "appSignature", type: .bytes(length: nil))
        ]
        let outputs = [
            SolidityFunctionParameter(name: "", type: .bytes(length: 32))
        ]
        
        let method = SolidityPayableFunction(name: "postCommentWithSig", inputs: inputs, outputs: outputs, handler: self)
        
        // Convert metadata entries to SolidityValue array
        let metadataArray = commentData.metadata.map { entry in
            SolidityTuple([
                .bytes(entry.key),
                .bytes(entry.value)
            ])
        }
        
        let commentDataSol = SolidityTuple([
            .address(commentData.author),
            .address(commentData.app),
            .uint(commentData.channelId),
            .uint(commentData.deadline),
            .fixedBytes(commentData.parentId),
            .uint(commentData.commentType),
            .string(commentData.content),
            .array(metadataArray, elementType: metadataEntryType),
            .string(commentData.targetUri)
        ])
        
        return method.invoke(
            commentDataSol,
            authorSignature,
            appSignature
        )
    }
    
    func getCommentId(commentData: CreateComment) -> SolidityInvocation {
        // Define the MetadataEntry tuple type
        let metadataEntryType = SolidityType.tuple([
            SolidityType.bytes(length: 32), // key
            SolidityType.bytes(length: nil)    // value
        ])
        
        // Define the CreateComment tuple type
        let createCommentType = SolidityType.tuple([
            SolidityType.address,     // author
            SolidityType.address,     // app
            SolidityType.uint256,     // channelId
            SolidityType.uint256,     // deadline
            SolidityType.bytes(length: 32),     // parentId
            SolidityType.uint8,       // commentType
            SolidityType.string,      // content
            SolidityType.array(type: metadataEntryType, length: nil),
            SolidityType.string       // targetUri
        ])
        
        let inputs = [
            SolidityFunctionParameter(name: "commentData", type: createCommentType)
        ]
        let outputs = [
            SolidityFunctionParameter(name: "", type: .bytes(length: 32))
        ]
        
        let method = SolidityConstantFunction(name: "getCommentId", inputs: inputs, outputs: outputs, handler: self)
        
        // Convert metadata entries to SolidityValue array
        let metadataArray = commentData.metadata.map { entry in
            SolidityTuple([
                .bytes(entry.key),
                .bytes(entry.value)
            ])
        }
        
        let commentDataSol = SolidityTuple([
            .address(commentData.author),
            .address(commentData.app),
            .uint(commentData.channelId),
            .uint(commentData.deadline),
            .fixedBytes(commentData.parentId),
            .uint(commentData.commentType),
            .string(commentData.content),
            .array(metadataArray, elementType: metadataEntryType),
            .string(commentData.targetUri)
        ])
        
        return method.invoke(commentDataSol)
    }
    
    func getDeleteCommentHash(commentId: Data, author: EthereumAddress, app: EthereumAddress, deadline: BigUInt) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "commentId", type: .bytes(length: 32)),
            SolidityFunctionParameter(name: "author", type: .address),
            SolidityFunctionParameter(name: "app", type: .address),
            SolidityFunctionParameter(name: "deadline", type: .uint256)
        ]
        let outputs = [
            SolidityFunctionParameter(name: "", type: .bytes(length: 32))
        ]
        
        let method = SolidityConstantFunction(name: "getDeleteCommentHash", inputs: inputs, outputs: outputs, handler: self)
        
        return method.invoke(
            commentId,
            author,
            app,
            deadline
        )
    }
    
    func deleteCommentWithSig(commentId: Data, app: EthereumAddress, deadline: BigUInt, authorSignature: Data, appSignature: Data) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "commentId", type: .bytes(length: 32)),
            SolidityFunctionParameter(name: "app", type: .address),
            SolidityFunctionParameter(name: "deadline", type: .uint256),
            SolidityFunctionParameter(name: "authorSignature", type: .bytes(length: nil)),
            SolidityFunctionParameter(name: "appSignature", type: .bytes(length: nil))
        ]
        let outputs: [SolidityFunctionParameter] = []
        
        let method = SolidityNonPayableFunction(name: "deleteCommentWithSig", inputs: inputs, outputs: outputs, handler: self)
        
        return method.invoke(
            commentId,
            app,
            deadline,
            authorSignature,
            appSignature
        )
    }
    
    func addApproval(app: EthereumAddress, expiry: BigUInt) -> SolidityInvocation {
        let inputs = [
            SolidityFunctionParameter(name: "app", type: .address),
            SolidityFunctionParameter(name: "expiry", type: .uint256)
        ]
        let outputs: [SolidityFunctionParameter] = []
        
        let method = SolidityNonPayableFunction(name: "addApproval", inputs: inputs, outputs: outputs, handler: self)
        
        return method.invoke(
            app,
            expiry
        )
    }
}

// MARK: - Service class for managing comments contract interactions

@MainActor
public class CommentsContractService: ObservableObject {
    @Published public var isApproved: Bool? = nil
    @Published public var isLoading = false
    @Published public var error: String?
    
    private let web3: Web3
    private let contract: GenericCommentsContract
    private let contractAddress = "0xb262C9278fBcac384Ef59Fc49E24d800152E19b1"
    
    public init() {
        // Initialize Web3 with Base mainnet RPC
        self.web3 = Web3(rpcURL: "https://mainnet.base.org")
        
        // Initialize the contract
        do {
            let address = try EthereumAddress(hex: contractAddress, eip55: true)
            self.contract = web3.eth.Contract(type: GenericCommentsContract.self, address: address)
        } catch {
            fatalError("Failed to initialize contract: \(error)")
        }
    }
    
    // MARK: - Gas Estimation
    
    /// Estimate gas for a transaction
    private func estimateGas(for invocation: SolidityInvocation, from address: EthereumAddress, value: EthereumQuantity? = nil) async throws -> EthereumQuantity {
        return try await withCheckedThrowingContinuation { continuation in
            if let value = value {
                invocation.estimateGas(from: address, value: value) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let gasEstimate = result {
                        // Add 20% buffer for safety
                        let gasWithBuffer = gasEstimate.quantity * 120 / 100
                        continuation.resume(returning: EthereumQuantity(quantity: gasWithBuffer))
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to estimate gas"]))
                    }
                }
            } else {
                invocation.estimateGas(from: address) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let gasEstimate = result {
                        // Add 20% buffer for safety
                        let gasWithBuffer = gasEstimate.quantity * 120 / 100
                        continuation.resume(returning: EthereumQuantity(quantity: gasWithBuffer))
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to estimate gas"]))
                    }
                }
            }
        }
    }
    
    // MARK: - Approval Methods
    
    public func checkApproval(authorAddress: String, appAddress: String) async {
        guard !authorAddress.isEmpty && !appAddress.isEmpty else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Validate address format before creating EthereumAddress objects
            let addressPattern = "^0x[a-fA-F0-9]{40}$"
            let authorValid = authorAddress.range(of: addressPattern, options: .regularExpression) != nil
            let appValid = appAddress.range(of: addressPattern, options: .regularExpression) != nil
            
            guard authorValid else {
                throw NSError(domain: "AddressValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid author address format"])
            }
            
            guard appValid else {
                throw NSError(domain: "AddressValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid app address format"])
            }
            
            // Normalize addresses to lowercase and create EthereumAddress objects
            let normalizedAuthor = authorAddress.lowercased()
            let normalizedApp = appAddress.lowercased()
            
            let authorAddr = try EthereumAddress(hex: normalizedAuthor, eip55: false)
            let appAddr = try EthereumAddress(hex: normalizedApp, eip55: false)
            
            // Perform contract call
            await performContractCall(authorAddr: authorAddr, appAddr: appAddr)
            
        } catch {
            self.error = "Failed to check approval: \(error.localizedDescription)"
            self.isApproved = nil
        }
        
        isLoading = false
    }
    
    private func performContractCall(authorAddr: EthereumAddress, appAddr: EthereumAddress) async {
        await withCheckedContinuation { continuation in
            contract.isApproved(identityAddress: authorAddr, app: appAddr).call { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.error = "Failed to check approval: \(error.localizedDescription)"
                        self.isApproved = nil
                    } else if let result = result, let approved = result[""] as? Bool {
                        self.isApproved = approved
                    } else {
                        self.error = "Invalid response format"
                        self.isApproved = nil
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Comment Methods
    
    public func postComment(
        params: CommentParams,
        appSignature: Data,
        privateKey: String,
        valueWei: BigUInt? = nil
    ) async throws -> String {
        
        let identityAddr = try EthereumAddress(hex: params.identityAddress, eip55: false)
        let appAddr = try EthereumAddress(hex: params.appAddress, eip55: false)
        // Create comment data
        let commentDeadline = BigUInt(params.deadline)
        let parentId = params.parentId ?? Data(count: 32) // Empty parent ID for top-level comments
        
        let commentData = CreateComment(
            author: identityAddr,
            app: appAddr,
            channelId: params.channelId,
            deadline: commentDeadline,
            parentId: parentId,
            commentType: 0,
            content: params.content,
            metadata: params.metadata,
            targetUri: params.targetUri
        )
        // Create the transaction
        let ethPrivateKey = try EthereumPrivateKey(hexPrivateKey: privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)")        
        
        let nonce: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.getTransactionCount(address: ethPrivateKey.address, block: .latest) { response in
                switch response.status {
                case .success:
                    if let quantity = response.result {
                        continuation.resume(returning: quantity)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No result returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        print("🔧 Got transaction nonce: \(nonce.quantity)")
        
        // Get gas price from the node
        let gasPrice: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.gasPrice { response in
                switch response.status {
                case .success:
                    if let price = response.result {
                        continuation.resume(returning: price)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No gas price returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let invocation = contract.postCommentWithSig(
            commentData: commentData,
            authorSignature: Data(count: 32),
            appSignature: appSignature
        )
        
        // Value to attach for payable fee (if any)
        let txValue: EthereumQuantity = EthereumQuantity(quantity: valueWei ?? 0)
        print("🔎 [PostComment] valueWei=\(String(describing: valueWei)) -> txValue=\(txValue.quantity)")

        // Estimate gas for the transaction (ensure value is considered)
        let estimatedGas = try await estimateGas(for: invocation, from: ethPrivateKey.address, value: txValue)
        print("🔧 Estimated gas (with value): \(estimatedGas)")

        let transaction = invocation.createTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            gasLimit: estimatedGas,
            from: ethPrivateKey.address,
            value: txValue,
            accessList: [:],
            transactionType: .legacy
        )
        
        guard let signedTransaction = try transaction?.sign(with: ethPrivateKey, chainId: 8453) else {
            throw NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign transaction"])
        }
        
        let txHash: EthereumData = try await withCheckedThrowingContinuation { continuation in
            do {
                print("🔎 [PostComment] sending raw tx with value=\(txValue.quantity) gasPrice=\(gasPrice.quantity) nonce=\(nonce.quantity)")
                try web3.eth.sendRawTransaction(transaction: signedTransaction) { response in
                    switch response.status {
                    case .success:
                        if let hash = response.result {
                            print("✅ [PostComment] tx sent hash=\(hash.hex())")
                            continuation.resume(returning: hash)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No transaction hash returned"]))
                        }
                    case .failure(let error):
                        print("❌ [PostComment] sendRawTransaction error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                print("❌ [PostComment] exception before send: \(error)")
                continuation.resume(throwing: error)
            }
        }
        
        return txHash.hex()
    }

    // MARK: - Estimation Helpers

    /// Estimates the total wei required to post a comment, including gas and the channel fee value
    /// - Parameters:
    ///   - params: Comment parameters (content, channelId, etc.)
    ///   - appSignature: Optional app signature to improve gas estimation accuracy. If nil, a fallback gas limit will be used on estimation failure.
    ///   - privateKey: App's private key used to derive the sender address for gas estimation and to query balance
    ///   - valueWei: Optional value (channel fee) to attach
    /// - Returns: Tuple containing (requiredWei, gasLimit, gasPrice, balanceWei)
    public func estimatePostCost(
        params: CommentParams,
        appSignature: Data? = nil,
        privateKey: String,
        valueWei: BigUInt? = nil
    ) async -> (requiredWei: BigUInt, gasLimit: EthereumQuantity, gasPrice: EthereumQuantity, balanceWei: BigUInt)? {
        do {
            let appEthKey = try EthereumPrivateKey(hexPrivateKey: privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)")
            let identityAddr = try EthereumAddress(hex: params.identityAddress, eip55: false)
            let appAddr = appEthKey.address

            // Build comment data
            let commentDeadline = BigUInt(params.deadline)
            let parentId = params.parentId ?? Data(count: 32)
            let commentData = CreateComment(
                author: identityAddr,
                app: appAddr,
                channelId: params.channelId,
                deadline: commentDeadline,
                parentId: parentId,
                commentType: 0,
                content: params.content,
                metadata: params.metadata,
                targetUri: params.targetUri
            )

            // Invocation using optional app signature (fallback to empty if nil)
            let invocation = contract.postCommentWithSig(
                commentData: commentData,
                authorSignature: Data(count: 32),
                appSignature: appSignature ?? Data(count: 65)
            )

            // Gas price
            let gasPrice: EthereumQuantity = try await withCheckedThrowingContinuation { cont in
                web3.eth.gasPrice { response in
                    switch response.status {
                    case .success:
                        if let price = response.result { cont.resume(returning: price) } else {
                            cont.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No gas price returned"]))
                        }
                    case .failure(let error):
                        cont.resume(throwing: error)
                    }
                }
            }

            // Gas limit with fallback (consider value for estimation)
            let gasLimit: EthereumQuantity
            do {
                let valueQty = EthereumQuantity(quantity: valueWei ?? 0)
                gasLimit = try await estimateGas(for: invocation, from: appAddr, value: valueQty)
            } catch {
                // Fallback to a conservative gas limit if estimation fails
                let fallback: BigUInt = 250_000
                gasLimit = EthereumQuantity(quantity: fallback)
            }

            // Sender balance
            let balanceWei: BigUInt = try await withCheckedThrowingContinuation { cont in
                web3.eth.getBalance(address: appAddr, block: .latest) { response in
                    switch response.status {
                    case .success:
                        if let bal = response.result?.quantity { cont.resume(returning: bal) } else {
                            cont.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No balance returned"]))
                        }
                    case .failure(let error):
                        cont.resume(throwing: error)
                    }
                }
            }

            // Total required wei = value + gasPrice * gasLimit
            let value = valueWei ?? 0
            let required = value + (gasPrice.quantity * gasLimit.quantity)
            return (requiredWei: required, gasLimit: gasLimit, gasPrice: gasPrice, balanceWei: balanceWei)
        } catch {
            print("❌ [EstimatePostCost] failed: \(error)")
            return nil
        }
    }
    
    public func getCommentId(params: CommentParams) async throws -> String {
        
        let identityAddr = try EthereumAddress(hex: params.identityAddress, eip55: false)
        let appAddr = try EthereumAddress(hex: params.appAddress, eip55: false)
        // Create comment data
        let commentDeadline = BigUInt(params.deadline)
        let commentParentId = params.parentId ?? Data(count: 32) // Empty parent ID for top-level comments
        
        let commentData = CreateComment(
            author: identityAddr,
            app: appAddr,
            channelId: params.channelId,
            deadline: commentDeadline,
            parentId: commentParentId,
            commentType: 0, // Standard comment type
            content: params.content,
            metadata: params.metadata,
            targetUri: params.targetUri
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            contract.getCommentId(commentData: commentData).call { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, let commentIdData = result[""] as? Data {
                    let commentIdHex = commentIdData.toHexString()
                    continuation.resume(returning: commentIdHex)
                } else {
                    continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                }
            }
        }
    }
    
    public func getDeleteCommentHash(commentId: String, author: String, app: String, deadline: TimeInterval) async throws -> String {
        let commentIdData = Data(hex: commentId)
        let authorAddr = try EthereumAddress(hex: author, eip55: false)
        let appAddr = try EthereumAddress(hex: app, eip55: false)
        let deadlineBigUInt = BigUInt(deadline)
        
        return try await withCheckedThrowingContinuation { continuation in
            contract.getDeleteCommentHash(commentId: commentIdData, author: authorAddr, app: appAddr, deadline: deadlineBigUInt).call { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, let hashData = result[""] as? Data {
                    continuation.resume(returning: hashData.toHexString())
                } else {
                    continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                }
            }
        }
    }
    
    public func deleteComment(
        commentId: String,
        appAddress: String,
        deadline: TimeInterval,
        authorSignature: Data,
        appSignature: Data,
        privateKey: String
    ) async throws -> String {
        
        let commentIdData = Data(hex: commentId)
        let appAddr = try EthereumAddress(hex: appAddress, eip55: false)
        let deadlineBigUInt = BigUInt(deadline)
        
        // Create the transaction
        let ethPrivateKey = try EthereumPrivateKey(hexPrivateKey: privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)")
        
        let nonce: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.getTransactionCount(address: ethPrivateKey.address, block: .latest) { response in
                switch response.status {
                case .success:
                    if let quantity = response.result {
                        continuation.resume(returning: quantity)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No result returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Get gas price from the node
        let gasPrice: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.gasPrice { response in
                switch response.status {
                case .success:
                    if let price = response.result {
                        continuation.resume(returning: price)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No gas price returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let invocation = contract.deleteCommentWithSig(
            commentId: commentIdData,
            app: appAddr,
            deadline: deadlineBigUInt,
            authorSignature: authorSignature,
            appSignature: appSignature
        )
        
        // Estimate gas for the transaction
        let estimatedGas = try await estimateGas(for: invocation, from: ethPrivateKey.address)
        print("🔧 Estimated gas for delete: \(estimatedGas)")
        
        let transaction = invocation.createTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            gasLimit: estimatedGas,
            from: ethPrivateKey.address,
            value: 0,
            accessList: [:],
            transactionType: .legacy
        )
        
        guard let signedTransaction = try transaction?.sign(with: ethPrivateKey, chainId: 8453) else {
            throw NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign transaction"])
        }
        
        let txHash: EthereumData = try await withCheckedThrowingContinuation { continuation in
            do {
                try web3.eth.sendRawTransaction(transaction: signedTransaction) { response in
                    switch response.status {
                    case .success:
                        if let hash = response.result {
                            continuation.resume(returning: hash)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No transaction hash returned"]))
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        return txHash.hex()
    }
    
    public func addApproval(
        appAddress: String,
        expiry: TimeInterval,
        privateKey: String
    ) async throws -> String {
        
        let appAddr = try EthereumAddress(hex: appAddress, eip55: false)
        let expiryBigUInt = BigUInt(expiry)
        
        // Create the transaction
        let ethPrivateKey = try EthereumPrivateKey(hexPrivateKey: privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)")
        
        let nonce: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.getTransactionCount(address: ethPrivateKey.address, block: .latest) { response in
                switch response.status {
                case .success:
                    if let quantity = response.result {
                        continuation.resume(returning: quantity)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No result returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Get gas price from the node
        let gasPrice: EthereumQuantity = try await withCheckedThrowingContinuation { continuation in
            web3.eth.gasPrice { response in
                switch response.status {
                case .success:
                    if let price = response.result {
                        continuation.resume(returning: price)
                    } else {
                        continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No gas price returned"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let invocation = contract.addApproval(
            app: appAddr,
            expiry: expiryBigUInt
        )
        
        // Estimate gas for the transaction
        let estimatedGas = try await estimateGas(for: invocation, from: ethPrivateKey.address)
        print("🔧 Estimated gas for approval: \(estimatedGas)")
        
        let transaction = invocation.createTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            gasLimit: estimatedGas,
            from: ethPrivateKey.address,
            value: 0,
            accessList: [:],
            transactionType: .legacy
        )
        
        guard let signedTransaction = try transaction?.sign(with: ethPrivateKey, chainId: 8453) else {
            throw NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign transaction"])
        }
        
        let txHash: EthereumData = try await withCheckedThrowingContinuation { continuation in
            do {
                try web3.eth.sendRawTransaction(transaction: signedTransaction) { response in
                    switch response.status {
                    case .success:
                        if let hash = response.result {
                            continuation.resume(returning: hash)
                        } else {
                            continuation.resume(throwing: NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No transaction hash returned"]))
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        return txHash.hex()
    }
    
    public func getApprovalTransactionData(appAddress: String, expiry: TimeInterval) throws -> String {
        let appAddr = try EthereumAddress(hex: appAddress, eip55: false)
        let expiryBigUInt = BigUInt(expiry)
        
        let invocation = contract.addApproval(app: appAddr, expiry: expiryBigUInt)
        
        // Get the encoded function data
        guard let encodedData = invocation.encodeABI() else {
            throw NSError(domain: "CommentsContractService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode transaction data"])
        }
        
        return encodedData.hex()
    }
} 
