//
//  InMemoryStore.swift
//  FuelingModel
//

import CoreModel

/// An in-memory `ModelStorage` **and** `ViewContext` backed by a plain
/// dictionary, using CoreModel's pure-Swift `FetchRequest.evaluate` engine.
///
/// The cross-platform, dependency-free storage backend — used where neither
/// `CoreDataModel` (Darwin) nor the SQLite backend are available. In
/// particular the browser/wasm target: the SQLite package pulls in SQLCipher's
/// libtomcrypt C code, which doesn't compile for `wasm32-unknown-wasip1`
/// (it needs `_WASI_EMULATED_SIGNAL`), so `Store+SQLite` is off the table there.
///
/// Single-object design: the *same* instance is handed to `Store` as both its
/// asynchronous `storage` and its synchronous `viewContext`, so UI reads
/// always observe prior writes. This is sound because the whole app runs on
/// the main actor — the class is `@MainActor`, so its `ModelStorage` async
/// methods and its `ViewContext` sync methods share one isolation domain and
/// one copy of the data.
@MainActor
public final class InMemoryStore {

    /// The schema this store validates entities against.
    public let model: Model

    /// `entity name -> (object id -> object)`.
    private var objects = [EntityName: [ObjectID: ModelData]]()

    /// Custom functions registered for predicate/sort evaluation.
    private var functions = [String: DatabaseFunction]()

    /// Initialize an empty store validating entities against the given schema.
    public init(model: Model) {
        self.model = model
    }

    // MARK: - Core (synchronous)

    private func read(_ entity: EntityName, for id: ObjectID) throws -> ModelData? {
        try validate(entity)
        return objects[entity]?[id]
    }

    private func read(_ fetchRequest: FetchRequest) throws -> [ModelData] {
        try validate(fetchRequest.entity)
        let all = objects[fetchRequest.entity].map { Array($0.values) } ?? []
        return fetchRequest.evaluate(all, functions: functions)
    }

    private func write(_ value: ModelData) throws {
        try validate(value.entity)
        // Upsert as a *partial* update, merging the provided keys over any
        // existing object rather than replacing it wholesale. This matches the
        // SQL/CoreData backends and preserves relationships a caller left out
        // on purpose (e.g. a location refresh that deliberately omits
        // `fuelProducts` so it never severs cached price links).
        var merged = objects[value.entity]?[value.id] ?? ModelData(entity: value.entity, id: value.id)
        merged.attributes.merge(value.attributes) { _, new in new }
        merged.relationships.merge(value.relationships) { _, new in new }
        // Fill in any schema-declared property still missing with a null/empty
        // default, so a freshly-inserted object decodes the same way it would
        // after a round trip through a database (unset attribute → null, unset
        // to-many → empty, unset to-one → null) instead of throwing
        // `keyNotFound`. Callers that map DTOs to `ModelData` routinely omit
        // optional attributes (`lastViewed`, `brand`, …) and relationships they
        // don't want to overwrite.
        if let description = model[value.entity] {
            for attribute in description.attributes where merged.attributes[attribute.id] == nil {
                merged.attributes[attribute.id] = .null
            }
            for relationship in description.relationships where merged.relationships[relationship.id] == nil {
                switch relationship.type {
                case .toMany:
                    merged.relationships[relationship.id] = .toMany([])
                case .toOne:
                    merged.relationships[relationship.id] = .null
                }
            }
        }
        objects[value.entity, default: [:]][value.id] = merged
    }

    private func remove(_ entity: EntityName, for id: ObjectID) throws {
        try validate(entity)
        objects[entity]?[id] = nil
    }

    private func validate(_ entity: EntityName) throws {
        guard model[entity] != nil else {
            throw CoreModelError.invalidEntity(entity)
        }
    }
}

// MARK: - ViewContext (synchronous, main-actor UI reads)

extension InMemoryStore: ViewContext {

    public func fetch(_ entity: EntityName, for id: ObjectID) throws -> ModelData? {
        try read(entity, for: id)
    }

    public func fetch(_ fetchRequest: FetchRequest) throws -> [ModelData] {
        try read(fetchRequest)
    }

    public func fetchID(_ fetchRequest: FetchRequest) throws -> [ObjectID] {
        try read(fetchRequest).map { $0.id }
    }

    public func count(_ fetchRequest: FetchRequest) throws -> UInt {
        try UInt(read(fetchRequest).count)
    }
}

// MARK: - ModelStorage (asynchronous writes + reads)

extension InMemoryStore: ModelStorage {

    public func fetch(_ entity: EntityName, for id: ObjectID) async throws -> ModelData? {
        try read(entity, for: id)
    }

    public func fetch(_ fetchRequest: FetchRequest) async throws -> [ModelData] {
        try read(fetchRequest)
    }

    public func fetchID(_ fetchRequest: FetchRequest) async throws -> [ObjectID] {
        try read(fetchRequest).map { $0.id }
    }

    public func count(_ fetchRequest: FetchRequest) async throws -> UInt {
        try UInt(read(fetchRequest).count)
    }

    public func insert(_ value: ModelData) async throws {
        try write(value)
    }

    public func insert(_ values: [ModelData]) async throws {
        for value in values {
            try write(value)
        }
    }

    public func delete(_ entity: EntityName, for id: ObjectID) async throws {
        try remove(entity, for: id)
    }

    public func delete(_ entity: EntityName, for ids: [ObjectID]) async throws {
        for id in ids {
            try remove(entity, for: id)
        }
    }

    public func register(function: DatabaseFunction) async throws {
        functions[function.name] = function
    }
}
