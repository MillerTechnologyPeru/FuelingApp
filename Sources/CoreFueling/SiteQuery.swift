//
//  SiteQuery.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

// MARK: - Filtering

public extension Site {

    /// Composable filter for fetching sites.
    enum Query: Equatable, Hashable, Sendable {

        case name(String, StringOperator = .contains)
        case directions(String, StringOperator = .contains)
        case city(String, StringOperator = .contains)
        case address(String, StringOperator = .contains)
        case zipCode(String)
        case state(String)
        case fuelOption(FuelOption.ID)
        case lastViewed

        case and([Query])
        case or([Query])
    }
}

public extension Site.Query {

    typealias StringOperator = FetchRequest.Predicate.StringOperator
}

public extension FetchRequest.Predicate {

    enum StringOperator: Equatable, Hashable, Sendable {

        case equalTo
        case contains
    }
}

public extension Site.Query {

    /// Match sites whose name, city, directions, address, zip code or state contain the text.
    static func search(_ text: String) -> Site.Query {
        .or([
            .name(text, .contains),
            .city(text, .contains),
            .directions(text, .contains),
            .address(text, .contains),
            .zipCode(text),
            .state(text)
        ])
    }

    static func fuelOptions(_ fuelOptions: Set<FuelOption.ID>) -> Site.Query {
        .and(fuelOptions.map { .fuelOption($0) })
    }

    /// Build a query from optional search text, or `nil` to fetch all sites.
    static func search(_ text: String? = nil) -> Site.Query? {
        guard let text, text.isEmpty == false else {
            return nil
        }
        return .search(text)
    }
}

public extension Site.Query {

    var predicate: CoreModel.FetchRequest.Predicate {
        switch self {
        case .and(let queries):
            guard queries.isEmpty == false else {
                return .value(true)
            }
            return .compound(.and(queries.map({ $0.predicate })))
        case .or(let queries):
            guard queries.isEmpty == false else {
                return .value(true)
            }
            return .compound(.or(queries.map({ $0.predicate })))
        case .name(let text, .contains):
            return Site.CodingKeys.name.contains(text)
        case .name(let text, .equalTo):
            return Site.CodingKeys.name.equalTo(text)
        case .directions(let text, .contains):
            return Site.CodingKeys.directions.contains(text)
        case .directions(let text, .equalTo):
            return Site.CodingKeys.directions.equalTo(text)
        case .city(let text, .contains):
            return Site.CodingKeys.city.contains(text)
        case .city(let text, .equalTo):
            return Site.CodingKeys.city.equalTo(text)
        case .address(let text, .contains):
            return Site.CodingKeys.address.contains(text)
        case .address(let text, .equalTo):
            return Site.CodingKeys.address.equalTo(text)
        case .zipCode(let zipCode):
            return Site.CodingKeys.zipCode.contains(zipCode)
        case .state(let state):
            return Site.CodingKeys.state.equalTo(state)
        case .fuelOption(let fuelOption):
            return Site.CodingKeys.fuelOptions.compare(.any, .in, [], .relationship(.toMany([.init(fuelOption)])))
        case .lastViewed:
            return Site.CodingKeys.lastViewed.compare(.notEqualTo, .attribute(.null))
        }
    }
}

// MARK: - Predicate Helpers

internal extension CodingKey {

    func contains(
        _ text: String,
        options: Set<FetchRequest.Predicate.Comparison.Option> = [.caseInsensitive, .localeSensitive]
    ) -> CoreModel.FetchRequest.Predicate {
        guard text.isEmpty == false else {
            return .value(true)
        }
        return self.compare(.contains, options, .attribute(.string(text)))
    }

    func equalTo(
        _ text: String,
        options: Set<FetchRequest.Predicate.Comparison.Option> = [.caseInsensitive, .localeSensitive]
    ) -> CoreModel.FetchRequest.Predicate {
        guard text.isEmpty == false else {
            return .value(true)
        }
        return self.compare(.equalTo, options, .attribute(.string(text)))
    }
}

// MARK: - Fetching

public extension ViewContext {

    /// Fetch sites filtered by search text.
    func fetch(
        _ type: Site.Type,
        search text: String?
    ) throws -> [Site] {
        let predicate = Site.Query.search(text)?.predicate
        return try self.fetch(type, predicate: predicate)
    }
}

public extension ModelStorage {

    /// Fetch sites filtered by search text.
    func fetch(
        _ type: Site.Type,
        search text: String?
    ) async throws -> [Site] {
        let predicate = Site.Query.search(text)?.predicate
        return try await fetch(type, predicate: predicate)
    }

    /// Mark a site as viewed.
    func didView(
        _ id: Site.ID,
        date: Date = Date()
    ) async throws {
        let modelData = ModelData(
            entity: Site.entityName,
            id: ObjectID(id),
            attributes: [
                PropertyKey(Site.CodingKeys.lastViewed): .date(date)
            ]
        )
        try await insert(modelData)
    }
}
