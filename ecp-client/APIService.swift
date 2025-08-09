//
//  APIService.swift
//  ecp-client
//
//  Created by Stephan on 2025/08/02.
//

import Foundation

// MARK: - API Service
@MainActor
class APIService: ObservableObject {
    
    // MARK: - Private Properties
    private let baseURL: String = AppConfiguration.shared.baseURL
    private let authService: AuthService
    
    // MARK: - Initialization
    init(authService: AuthService) {
        self.authService = authService
    }
    
    // MARK: - Notification Methods
    
    /// Register device token for push notifications
    /// - Parameter deviceToken: The APNs device token
    /// - Returns: Success status
    func registerDeviceToken(_ deviceToken: String) async throws -> Bool {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["deviceToken": deviceToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationResult.self, from: data)
            return result.success
        } else if httpResponse.statusCode == 401 {
            // Token expired, try to re-authenticate
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let errorMessage = errorResult?.error ?? "Unknown error"
            throw APIError.serverError(errorMessage)
        }
    }
    
    /// Get registered device tokens
    /// - Returns: Array of notification details
    func getDeviceTokens() async throws -> [NotificationDetails] {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationsResult.self, from: data)
            return result.notifications
        } else if httpResponse.statusCode == 401 {
            // Token expired, try to re-authenticate
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "Unknown error")
        }
    }

    /// Get notification registration status for current user
    func getNotificationStatus() async throws -> NotificationStatusResult {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/api/notifications/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationStatusResult.self, from: data)
            return result
        } else if httpResponse.statusCode == 401 {
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "Unknown error")
        }
    }
    
    /// Remove a device token
    /// - Parameter deviceToken: The device token to remove
    /// - Returns: Success status
    func removeDeviceToken(_ deviceToken: String) async throws -> Bool {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/notifications/\(deviceToken)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationResult.self, from: data)
            return result.success
        } else if httpResponse.statusCode == 401 {
            // Token expired, try to re-authenticate
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "Unknown error")
        }
    }
    
    /// Send a test notification
    /// - Returns: Success status
    func sendTestNotification() async throws -> Bool {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/notifications/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationResult.self, from: data)
            return result.success
        } else if httpResponse.statusCode == 401 {
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "Unknown error")
        }
    }

    // MARK: - Notification Events (History)

    /// Fetch historical notification events
    func getNotificationEvents(limit: Int = 50, cursor: String? = nil) async throws -> NotificationEventsPage {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }

        var components = URLComponents(string: "\(baseURL)/api/notifications/events")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor = cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        components.queryItems = queryItems
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(NotificationEventsPage.self, from: data)
            return result
        } else if httpResponse.statusCode == 401 {
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "Unknown error")
        }
    }

    // MARK: - Generic API Methods
    
    /// Make an authenticated API request
    /// - Parameters:
    ///   - url: The URL to request
    ///   - method: HTTP method
    ///   - body: Optional request body
    /// - Returns: Response data
    func makeAuthenticatedRequest(
        url: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let token = authService.getAuthToken() else {
            throw APIError.notAuthenticated
        }
        
        let requestUrl = URL(string: url)!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 401 {
            // Token expired, try to re-authenticate
            await authService.authenticate()
            throw APIError.authenticationExpired
        } else if httpResponse.statusCode >= 400 {
            let errorResult = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(errorResult?.error ?? "HTTP \(httpResponse.statusCode)")
        }
        
        return data
    }
}

// MARK: - API Models
struct NotificationResult: Codable {
    let success: Bool
    let message: String?
    let id: String?
}

struct NotificationsResult: Codable {
    let success: Bool
    let notifications: [NotificationDetails]
}

struct NotificationStatusResult: Codable {
    let success: Bool
    let registered: Bool
    let count: Int
    let tokens: [String]
    let details: [NotificationStatusDetail]?
}

struct NotificationStatusDetail: Codable {
    let deviceToken: String
    let createdAt: String
    let updatedAt: String
}

struct NotificationDetails: Codable, Identifiable {
    let id: String
    let deviceToken: String
    let createdAt: String
    let updatedAt: String
}

struct NotificationEventsPage: Codable {
    let success: Bool
    let events: [NotificationEvent]
    let nextCursor: String?
}

struct NotificationEvent: Codable, Identifiable {
    let id: String
    let type: String?
    let originAddress: String?
    let chainId: Int?
    let subjectCommentId: String?
    let targetCommentId: String?
    let parentCommentId: String?
    let reactionType: String?
    let groupKey: String?
    let title: String
    let body: String
    let badge: Int?
    let sound: String?
    let data: [String: JSONValue]? // arbitrary JSON payload
    let createdAt: String
    let actorProfile: AuthorProfile?
    let parentProfile: AuthorProfile?
}

// Author profile model mirrored from Indexer API subset
struct AuthorProfile: Codable {
    let address: String
    let ens: ENSProfile?
    let farcaster: FarcasterProfile?
}

struct ENSProfile: Codable {
    let name: String
    let avatarUrl: String?
}

struct FarcasterProfile: Codable {
    let fid: Int?
    let pfpUrl: String?
    let displayName: String?
    let username: String?
}

// Minimal JSON value to decode arbitrary notification data payloads
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let n = try? container.decode(Double.self) { self = .number(n); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let arr = try? container.decode([JSONValue].self) { self = .array(arr); return }
        if let obj = try? container.decode([String: JSONValue].self) { self = .object(obj); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case notAuthenticated
    case authenticationExpired
    case networkError(String)
    case serverError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .authenticationExpired:
            return "Authentication expired. Please sign in again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}