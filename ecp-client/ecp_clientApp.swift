//
//  ecp_clientApp.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI
import CoinbaseWalletSDK

@main
struct ecp_clientApp: App {
    
    init() {
        // Configure Coinbase Wallet SDK with the selected wallet
        WalletConfigurationService.shared.configureCoinbaseSDK()
        WalletConfigurationService.shared.markWalletAsConfigured()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeeplink(url: url)
                }
        }
    }
    
    private func handleDeeplink(url: URL) {
        // First, try to handle Coinbase Wallet SDK response
        if (try? CoinbaseWalletSDK.shared.handleResponse(url)) == true {
            return
        }
        
        // Handle other types of deep links here
        print("Received deeplink: \(url)")
        
        // Example: Add your custom deeplink handling
        // if url.scheme == "ecp-client" {
        //     switch url.host {
        //     case "comment":
        //         let commentId = url.pathComponents.last
        //         // Navigate to specific comment
        //     case "user":
        //         let userId = url.pathComponents.last
        //         // Navigate to user profile
        //     default:
        //         break
        //     }
        // }
    }
}
