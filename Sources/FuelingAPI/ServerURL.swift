//
//  ServerURL.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// Validated wrapper around the server base URL.
///
/// The base URL is always injected by the app; no production hostname is hardcoded.
public struct ServerURL: Codable, Equatable, Hashable, Sendable {

    internal let url: URL

    public init(url: URL) {
        self.url = url
    }
}

public extension URL {

    init(server: ServerURL) {
        self = server.url
    }
}

public extension ServerURL {

    var host: String {
        url.host ?? ""
    }

    func appending(_ pathComponent: String) -> ServerURL {
        assert(pathComponent.isEmpty == false)
        let url = url.appendingPathComponent(pathComponent)
        return ServerURL(url: url)
    }
}

// MARK: - RawRepresentable

extension ServerURL: RawRepresentable {

    public init?(rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return nil
        }
        self.init(url: url)
    }

    public var rawValue: String {
        url.absoluteString
    }
}

// MARK: - CustomStringConvertible

extension ServerURL: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue
    }

    public var debugDescription: String {
        rawValue
    }
}

// MARK: - Definitions

public extension ServerURL {

    /// Local development server.
    static func localhost(port: UInt = 8080) -> ServerURL {
        ServerURL(rawValue: "http://localhost:" + port.description)!
    }
}
