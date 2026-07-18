//
//  FuelingError.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// App-level error shared by services and view models.
public enum FuelingError: Swift.Error, Equatable, Hashable, Sendable {

    /// No service is configured for the requested operation.
    case serviceUnavailable

    /// The server returned a malformed or unexpected response.
    case invalidResponse

    /// The server returned an unexpected HTTP status code.
    case invalidStatusCode(Int)

    /// The server returned an error message.
    case errorResponse(String)

    /// A wrapped underlying error.
    case error(String)
}

public extension FuelingError {

    /// Wrap an arbitrary error, passing `FuelingError` values through unchanged.
    init(_ error: some Swift.Error) {
        if let error = error as? FuelingError {
            self = error
        } else {
            // `String(describing:)` needs runtime reflection, which Embedded Swift
            // lacks; the concrete error type isn't recoverable there.
            #if hasFeature(Embedded)
            self = .error("Unknown error")
            #else
            self = .error(String(describing: error))
            #endif
        }
    }

    /// Human-readable message for presentation.
    var message: String {
        switch self {
        case .serviceUnavailable:
            return "Service unavailable"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidStatusCode(let code):
            return "Unexpected status code \(code)"
        case .errorResponse(let message):
            return message
        case .error(let description):
            return description
        }
    }
}
