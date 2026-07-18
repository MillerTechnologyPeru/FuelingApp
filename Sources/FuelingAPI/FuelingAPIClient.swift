//
//  FuelingAPIClient.swift
//  FuelingAPI
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import HTTPTypes
import HTTPTypesFoundation
import CoreFueling

/// Fueling REST API, implemented over any ``HTTPClient`` transport.
///
/// The server base URL is injected per call; nothing is hardcoded.
public extension HTTPClient {

    /// Fetch the specified sites, or all sites if empty.
    ///
    /// `GET {server}/v1/locations`
    func locations(
        sites: [Site.ID] = [],
        server: ServerURL,
        device deviceID: String = "0"
    ) async throws(FuelingError) -> [Location] {
        try await request("v1/locations", sites: sites, server: server, device: deviceID)
    }

    /// Fetch fuel prices for the specified sites, or all sites if empty.
    ///
    /// `GET {server}/v1/fuelprice`
    func fuelPrices(
        for sites: [Site.ID] = [],
        server: ServerURL,
        device deviceID: String = "0"
    ) async throws(FuelingError) -> [FuelPrice] {
        try await request("v1/fuelprice", sites: sites, server: server, device: deviceID)
    }
}

internal extension HTTPClient {

    func request<T: Codable & Sendable>(
        _ path: String,
        sites: [Site.ID],
        server: ServerURL,
        device deviceID: String
    ) async throws(FuelingError) -> T {
        let url = FuelingAPI.url(for: path, sites: sites, server: server)
        let request = HTTPRequest(
            method: .get,
            url: url,
            headerFields: [
                .deviceID: deviceID
            ]
        )
        let (data, response): (Data, HTTPResponse)
        do {
            (data, response) = try await self.data(for: request)
        } catch {
            throw FuelingError(error)
        }
        guard response.status == .ok else {
            throw .invalidStatusCode(response.status.code)
        }
        let apiResponse: APIResponse<T>
        do {
            apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        } catch {
            throw .invalidResponse
        }
        return try apiResponse.get()
    }
}

/// Build the request URL for an endpoint.
internal func url(
    for path: String,
    sites: [Site.ID],
    server: ServerURL
) -> URL {
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

public extension HTTPField.Name {

    /// Unique device identifier header sent with each request.
    static var deviceID: HTTPField.Name {
        .init("Device-ID")!
    }
}
