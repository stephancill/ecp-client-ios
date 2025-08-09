//
//  IdentityService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/04.
//

import SwiftUI
import Web3

@MainActor
class IdentityService: ObservableObject {
    @Published var isIdentityConfigured = false
    @Published var isCheckingIdentity = true
    
    private let commentsService = CommentsContractService()
    
    func checkIdentityConfiguration() async {
        isCheckingIdentity = true
        
        do {
            let identityAddress = try KeychainManager.retrieveIdentityAddress()
            let hasIdentity = identityAddress != nil
            
            if hasIdentity {
                // If identity exists, also check approval status
                let privateKey = try KeychainManager.retrievePrivateKey()
                let formattedPrivateKey = privateKey.hasPrefix("0x") ? privateKey : "0x\(privateKey)"
                let ethereumPrivateKey = try EthereumPrivateKey(hexPrivateKey: formattedPrivateKey)
                let appAddress = ethereumPrivateKey.address.hex(eip55: true)
                
                await commentsService.checkApproval(authorAddress: identityAddress!, appAddress: appAddress)
                
                // User is configured if they have identity AND are approved
                isIdentityConfigured = commentsService.isApproved == true

                // Fire-and-forget backend sync of approvals whenever local approval is re-evaluated
                if let token = try? KeychainManager.retrieveJWTToken(), !token.isEmpty {
                    let authService = AuthService()
                    let api = APIService(authService: authService)
                    Task { try? await api.syncApprovals(chainId: 8453) }
                }
            } else {
                isIdentityConfigured = false
            }
        } catch {
            print("❌ Failed to check identity configuration: \(error)")
            isIdentityConfigured = false
        }
        
        isCheckingIdentity = false
    }
} 