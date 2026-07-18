//
//  FuelingAPIClient.swift
//  FuelingAPI
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CoreFueling

/// Client for the fueling REST API.
public protocol FuelingAPIClient: Sendable {

    /// Fetch the specified sites, or all sites if empty.
    func locations(sites: [Site.ID]) async throws(FuelingError) -> [Location]

    /// Fetch fuel prices for the specified sites, or all sites if empty.
    func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> [FuelPrice]
}

public extension FuelingAPIClient {

    /// Fetch all sites.
    func locations() async throws(FuelingError) -> [Location] {
        try await locations(sites: [])
    }
}

// MARK: - URLSession Client

/// `URLSession`-backed implementation of ``FuelingAPIClient``.
///
/// The server base URL is injected at initialization.
public struct URLSessionFuelingAPIClient: FuelingAPIClient {

    /// Base URL of the server.
    public let server: ServerURL

    /// Unique device identifier sent with each request.
    public let deviceID: String

    internal let session: URLSession

    public init(
        server: ServerURL,
        deviceID: String = "0",
        session: URLSession = .shared
    ) {
        self.server = server
        self.deviceID = deviceID
        self.session = session
    }

    public func locations(sites: [Site.ID]) async throws(FuelingError) -> [Location] {
        try await request("v1/locations", sites: sites)
    }

    public func fuelPrices(for sites: [Site.ID]) async throws(FuelingError) -> [FuelPrice] {
        try await request("v1/fuelprice", sites: sites)
    }
}

internal extension URLSessionFuelingAPIClient {

    func request<T: Decodable & Sendable>(
        _ path: String,
        sites: [Site.ID]
    ) async throws(FuelingError) -> T {
        let url = url(path: path, sites: sites)
        var request = URLRequest(url: url)
        request.setValue(deviceID, forHTTPHeaderField: "Device-ID")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FuelingError(error)
        }
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw .invalidStatusCode(httpResponse.statusCode)
            }
        }
        let apiResponse: APIResponse<T>
        do {
            apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        } catch {
            throw .invalidResponse
        }
        return try apiResponse.get()
    }

    func url(path: String, sites: [Site.ID]) -> URL {
        var components = URLComponents(
            url: URL(server: server).appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if sites.isEmpty == false {
            components.queryItems = sites.map {
                URLQueryItem(name: "siteIds", value: Site.ID.Prefixed(id: $0).rawValue)
            }
        }
        return components.url!
    }
}
