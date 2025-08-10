//
//  ImageUploadService.swift
//  ecp-client
//
//  Image upload service for Pinata integration
//

import Foundation
import UIKit

struct PinataUploadResponse: Codable {
    let data: PinataUploadData
}

struct PinataUploadData: Codable {
    let id: String
    let name: String
    let cid: String
    let size: Int
    let numberOfFiles: Int
    let mimeType: String
    let groupId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, cid, size
        case numberOfFiles = "number_of_files"
        case mimeType = "mime_type"
        case groupId = "group_id"
    }
}

class ImageUploadService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadError: String?
    
    func uploadImage(_ image: UIImage) async throws -> String {
        guard !AppConfiguration.shared.pinataJWT.isEmpty else {
            throw ImageUploadError.missingConfiguration
        }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            uploadError = nil
        }
        
        defer {
            Task { @MainActor in
                isUploading = false
                uploadProgress = 0.0
            }
        }
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageUploadError.imageConversionFailed
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add network parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"network\"\r\n\r\n".data(using: .utf8)!)
        body.append("public".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        guard let url = URL(string: "https://uploads.pinata.cloud/v3/files") else {
            throw ImageUploadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfiguration.shared.pinataJWT)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        // Update progress
        await MainActor.run {
            uploadProgress = 0.5
        }
        
        // Perform upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Update progress
        await MainActor.run {
            uploadProgress = 0.9
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageUploadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageUploadError.uploadFailed(httpResponse.statusCode, errorMessage)
        }
        
        // Parse response
        let uploadResponse = try JSONDecoder().decode(PinataUploadResponse.self, from: data)
        
        // Construct image URL using gateway
        let imageURL = "https://\(AppConfiguration.shared.pinataGatewayURL)/ipfs/\(uploadResponse.data.cid)"
        
        // Update progress
        await MainActor.run {
            uploadProgress = 1.0
        }
        
        return imageURL
    }
}

enum ImageUploadError: LocalizedError {
    case missingConfiguration
    case imageConversionFailed
    case invalidURL
    case invalidResponse
    case uploadFailed(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Pinata configuration is missing"
        case .imageConversionFailed:
            return "Failed to convert image to JPEG"
        case .invalidURL:
            return "Invalid upload URL"
        case .invalidResponse:
            return "Invalid server response"
        case .uploadFailed(let code, let message):
            return "Upload failed (\(code)): \(message)"
        }
    }
}