//
//  HTTPClient.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import HTTPTypes

/// Abstraction over an HTTP transport.
///
/// The API endpoints are implemented as extensions of this protocol, so any
/// transport (e.g. `URLSession`, a mock, or a custom networking stack) can
/// execute them by providing a single primitive.
public protocol HTTPClient: Sendable {

    associatedtype HTTPError: Swift.Error

    /// Execute the request and return the response body and metadata.
    func data(
        for request: HTTPRequest
    ) async throws(HTTPError) -> (Data, HTTPResponse)
}
