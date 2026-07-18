//
//  APIResponse.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreFueling

/// Generic `{ status, message, data }` envelope returned by every endpoint.
public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {

    public let status: Status

    public let message: String?

    public let data: T?

    public init(
        status: Status = .success,
        message: String? = nil,
        data: T? = nil
    ) {
        self.status = status
        self.message = message
        self.data = data
    }

    public enum CodingKeys: String, CodingKey {
        case status
        case message
        case data
    }
}

public extension APIResponse {

    enum Status: String, Codable, Sendable {

        case success = "Success"
        case error = "Error"
    }
}

public extension APIResponse {

    /// Unwrap the payload, converting an error status into a thrown error.
    func get() throws(FuelingError) -> T {
        guard status == .success, let data else {
            throw .errorResponse(message ?? "Request failed")
        }
        return data
    }
}
