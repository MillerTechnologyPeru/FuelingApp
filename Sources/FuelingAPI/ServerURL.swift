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

// MARK: - Environment Injection

public extension ServerURL {

    /// Build a server URL from an environment variable, falling back to
    /// `default` (`.localhost()`) when the variable is unset or invalid.
    ///
    /// Keeps the base URL out of source control entirely — inject it at
    /// launch (e.g. an Xcode scheme's environment variables, a shell
    /// `export`, or a CI secret) rather than hardcoding it anywhere in the
    /// package. On Android, where installed apps don't inherit a shell
    /// environment, the equivalent value is baked into `BuildConfig` from a
    /// Gradle-time environment variable instead — see
    /// `Android/app/build.gradle.kts`.
    static func fromEnvironment(
        _ variableName: String = "FUELING_SERVER_URL",
        default fallback: @autoclosure () -> ServerURL = .localhost()
    ) -> ServerURL {
        guard let rawValue = ProcessInfo.processInfo.environment[variableName],
            let serverURL = ServerURL(rawValue: rawValue)
        else {
            return fallback()
        }
        return serverURL
    }
}
