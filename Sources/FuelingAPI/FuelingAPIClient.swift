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
import CoreFueling

/// Fueling REST API, implemented over any ``HTTPClient`` transport.
///
/// The server base URL is injected per call; nothing is hardcoded.
public extension HTTPClient {

    /// Fetch the specified locations, or all locations if empty.
    ///
    /// `GET {server}/v1/locations`
    func locations(
        ids: [Location.ID] = [],
        server: ServerURL,
        device deviceID: String = "0"
    ) async throws(FuelingError) -> [GetLocation] {
        try await request("v1/locations", ids: ids, server: server, device: deviceID)
    }

    /// Fetch fuel prices for the specified locations, or all locations if empty.
    ///
    /// `GET {server}/v1/fuelprice`
    func fuelPrices(
        for locations: [Location.ID] = [],
        server: ServerURL,
        device deviceID: String = "0"
    ) async throws(FuelingError) -> [FuelPrice] {
        try await request("v1/fuelprice", ids: locations, server: server, device: deviceID)
    }
}

internal extension HTTPClient {

    func request<T: Codable & Sendable>(
        _ path: String,
        ids: [Location.ID],
        server: ServerURL,
        device deviceID: String
    ) async throws(FuelingError) -> T {
        // Built from URLComponents rather than `HTTPRequest(method:url:...)` —
        // that convenience initializer lives in `HTTPTypesFoundation`, whose
        // `URLSession` bridging drags `FoundationNetworking` (and its ~42 MB
        // ICU dependency chain) into the Android link. Pure `HTTPTypes` keeps
        // this module transport-agnostic on every platform.
        let components = FuelingAPI.urlComponents(for: path, ids: ids, server: server)
        var requestPath = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            requestPath += "?" + query
        }
        var authority = components.host ?? ""
        if let port = components.port {
            authority += ":" + port.description
        }
        let request = HTTPRequest(
            method: .get,
            scheme: components.scheme,
            authority: authority,
            path: requestPath,
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

/// Build the request URL components for an endpoint.
internal func urlComponents(
    for path: String,
    ids: [Location.ID],
    server: ServerURL
) -> URLComponents {
    var components = URLComponents(
        url: URL(server: server).appendingPathComponent(path),
        resolvingAgainstBaseURL: false
    )!
    if ids.isEmpty == false {
        components.queryItems = ids.map {
            URLQueryItem(name: "siteIds", value: Location.ID.Prefixed(id: $0).rawValue)
        }
    }
    return components
}

public extension HTTPField.Name {

    /// Unique device identifier header sent with each request.
    static var deviceID: HTTPField.Name {
        .init("Device-ID")!
    }
}
