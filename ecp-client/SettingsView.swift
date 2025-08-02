//
//  SettingsView.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var privateKey: String = ""
    @State private var isPrivateKeyVisible = false
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Private Key"),
                    footer: Text("Keep your private key secure. Anyone with access to this key can control your account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                ) {
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
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = privateKey
                        }) {
                            Label("Copy Private Key", systemImage: "doc.on.doc")
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
        } catch {
            // Generate a new private key if none exists
            generateNewPrivateKey()
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
        } catch {
            // Handle error - could show an alert here
            print("Failed to store private key: \(error)")
        }
    }
}

#Preview("Settings") {
    SettingsView()
} 