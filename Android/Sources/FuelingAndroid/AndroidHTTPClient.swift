//
//  AndroidHTTPClient.swift
//  FuelingAndroid
//
//  Adapts a Kotlin/Java-backed `AndroidHTTPTransport` callback into the
//  `HTTPClient` protocol that `APILocationService` expects.
//
//  Deliberately `internal`, not `public`: pure implementation detail,
//  constructed only inside `FuelingSession.init`, so jextract never generates
//  standalone JNI bindings for it (mirroring the screen adapters' pattern).
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Dispatch
import HTTPTypes
import CoreFueling
import FuelingAPI

/// Bridges the synchronous, blocking ``AndroidHTTPTransport`` JNI callback
/// into `HTTPClient`'s `async throws` requirement.
final class AndroidHTTPClient: HTTPClient, @unchecked Sendable {

    /// Kotlin/Java-backed transport. JNI callback objects are plain Java
    /// references — thread-confinement is provided by `queue`, not the type.
    private let transport: any AndroidHTTPTransport

    /// Serial queue the blocking JNI upcall runs on. A dedicated dispatch
    /// queue (a real OS thread) rather than the caller's Swift Concurrency
    /// cooperative pool, which must never be blocked on synchronous I/O.
    /// Serial execution also makes the transport's stateful
    /// `send` → `response*()` sequence atomic per request.
    private let queue: DispatchQueue

    init(transport: any AndroidHTTPTransport) {
        self.transport = transport
        self.queue = DispatchQueue(label: "com.fuelingapp.AndroidHTTPClient")
    }

    // Untyped `throws` (`HTTPError == any Error`), matching the shape of the
    // `URLSession` conformance: a typed-`throws(FuelingError)` witness here
    // miscompiled on the Android toolchain — the resulting
    // `APILocationService<AndroidHTTPClient>` existential box crashed
    // (SIGSEGV) or silently became `nil` when copied.
    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse) {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [transport] in
                do {
                    continuation.resume(returning: try Self.perform(request, transport: transport))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func perform(
        _ request: HTTPRequest,
        transport: any AndroidHTTPTransport
    ) throws -> (Data, HTTPResponse) {
        guard let scheme = request.scheme,
            let authority = request.authority
        else {
            throw FuelingError.error("Invalid request: missing scheme or authority")
        }
        let url = scheme + "://" + authority + (request.path ?? "/")
        var headerNames = [String]()
        var headerValues = [String]()
        headerNames.reserveCapacity(request.headerFields.count)
        headerValues.reserveCapacity(request.headerFields.count)
        for field in request.headerFields {
            headerNames.append(field.name.rawName)
            headerValues.append(field.value)
        }
        let statusCode = try transport.send(
            method: request.method.rawValue,
            url: url,
            headerNames: headerNames,
            headerValues: headerValues
        )
        let responseNames = transport.responseHeaderNames()
        let responseValues = transport.responseHeaderValues()
        let body = transport.responseBody().withUnsafeBytes { Data($0) }
        var responseFields = HTTPFields()
        for (name, value) in zip(responseNames, responseValues) {
            guard let fieldName = HTTPField.Name(name) else { continue }
            responseFields.append(HTTPField(name: fieldName, value: value))
        }
        let response = HTTPResponse(
            status: HTTPResponse.Status(code: Int(statusCode)),
            headerFields: responseFields
        )
        return (body, response)
    }
}
