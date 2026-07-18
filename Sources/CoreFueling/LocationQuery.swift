//
//  LocationQuery.swift
//  CoreFueling
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import CoreModel

// MARK: - Filtering

public extension Location {

    /// Composable filter for fetching locations.
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

public extension Location.Query {

    typealias StringOperator = FetchRequest.Predicate.StringOperator
}

public extension FetchRequest.Predicate {

    enum StringOperator: Equatable, Hashable, Sendable {

        case equalTo
        case contains
    }
}

public extension Location.Query {

    /// Match locations whose name, city, directions, address, zip code or state contain the text.
    static func search(_ text: String) -> Location.Query {
        .or([
            .name(text, .contains),
            .city(text, .contains),
            .directions(text, .contains),
            .address(text, .contains),
            .zipCode(text),
            .state(text)
        ])
    }

    static func fuelOptions(_ fuelOptions: Set<FuelOption.ID>) -> Location.Query {
        .and(fuelOptions.map { .fuelOption($0) })
    }

    /// Build a query from optional search text, or `nil` to fetch all locations.
    static func search(_ text: String? = nil) -> Location.Query? {
        guard let text, text.isEmpty == false else {
            return nil
        }
        return .search(text)
    }
}

public extension Location.Query {

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
            return Location.CodingKeys.name.contains(text)
        case .name(let text, .equalTo):
            return Location.CodingKeys.name.equalTo(text)
        case .directions(let text, .contains):
            return Location.CodingKeys.directions.contains(text)
        case .directions(let text, .equalTo):
            return Location.CodingKeys.directions.equalTo(text)
        case .city(let text, .contains):
            return Location.CodingKeys.city.contains(text)
        case .city(let text, .equalTo):
            return Location.CodingKeys.city.equalTo(text)
        case .address(let text, .contains):
            return Location.CodingKeys.address.contains(text)
        case .address(let text, .equalTo):
            return Location.CodingKeys.address.equalTo(text)
        case .zipCode(let zipCode):
            return Location.CodingKeys.zipCode.contains(zipCode)
        case .state(let state):
            return Location.CodingKeys.state.equalTo(state)
        case .fuelOption(let fuelOption):
            return Location.CodingKeys.fuelOptions.compare(.any, .in, [], .relationship(.toMany([.init(fuelOption)])))
        case .lastViewed:
            return Location.CodingKeys.lastViewed.compare(.notEqualTo, .attribute(.null))
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

// `ViewContext` and the generic `Entity`-based `ModelStorage.fetch<T>`/`insert<T>`
// convenience methods these build on are both unavailable under Embedded Swift
// (see CoreModel's README) — `ViewContext` doesn't exist there, and the generic
// helpers hit a compiler limitation with `async` default protocol-extension
// methods dispatching through `Self`. Embedded callers build `FetchRequest`/
// `ModelData` directly against the `ModelStorage` requirements.
#if !hasFeature(Embedded)

public extension ViewContext {

    /// Fetch locations filtered by search text.
    func fetch(
        _ type: Location.Type,
        search text: String?
    ) throws -> [Location] {
        let predicate = Location.Query.search(text)?.predicate
        return try self.fetch(type, predicate: predicate)
    }
}

public extension ModelStorage {

    /// Fetch locations filtered by search text.
    func fetch(
        _ type: Location.Type,
        search text: String?
    ) async throws -> [Location] {
        let predicate = Location.Query.search(text)?.predicate
        return try await fetch(type, predicate: predicate)
    }

    /// Mark a location as viewed.
    func didView(
        _ id: Location.ID,
        date: Date = Date()
    ) async throws {
        let modelData = ModelData(
            entity: Location.entityName,
            id: ObjectID(id),
            attributes: [
                PropertyKey(Location.CodingKeys.lastViewed): .date(date)
            ]
        )
        try await insert(modelData)
    }
}

#endif
