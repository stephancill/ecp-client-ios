//
//  AppConfiguration.swift
//  ecp-client
//
//  Centralized runtime configuration.
//

import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()

    let baseURL: String

    private init() {
        // Priority: Info.plist -> process env (useful for previews/tests) -> safe default
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           plistValue.isEmpty == false {
            baseURL = AppConfiguration.normalizeBaseURL(plistValue)
        } else if let envValue = ProcessInfo.processInfo.environment["API_BASE_URL"],
                  envValue.isEmpty == false {
            baseURL = AppConfiguration.normalizeBaseURL(envValue)
        } else {
            baseURL = AppConfiguration.normalizeBaseURL("https://example.com")
        }
    }

    private static func normalizeBaseURL(_ urlString: String) -> String {
        // Trim whitespace and any trailing slashes for consistent request building
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            return String(trimmed.dropLast())
        }
        return trimmed
    }
}

