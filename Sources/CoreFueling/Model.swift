//
//  Model.swift
//  CoreFueling
//

import CoreModel

#if !hasFeature(Embedded)
public extension Model {

    /// CoreModel schema for the fueling domain.
    ///
    /// Built from concrete `EntityDescription` values rather than the variadic
    /// `Model(entities: any Entity.Type...)`, which is unavailable under Embedded
    /// Swift (it dispatches through an existential metatype).
    static var fueling: Model {
        Model(
            entities: [
                EntityDescription(entity: Location.self),
                EntityDescription(entity: FuelProduct.self),
                EntityDescription(entity: FuelOption.self)
            ]
        )
    }
}
#else
public extension Model {

    /// CoreModel schema for the fueling domain.
    ///
    /// The Embedded declarations of `Location`/`FuelProduct`/`FuelOption` don't
    /// conform to `Entity` (see the note atop Location.swift), so
    /// `EntityDescription(entity:)` is unavailable — the descriptions are built
    /// directly from each entity's own attribute/relationship tables, which the
    /// Embedded branches expose as plain dictionaries. Consumed by
    /// `CoreModel.InMemoryStorage` (e.g. the Nintendo DS port's store).
    static var fueling: Model {
        Model(
            entities: [
                EntityDescription(
                    id: Location.entityName,
                    attributes: Location.attributes.map { Attribute(id: PropertyKey($0.key), type: $0.value) },
                    relationships: Array(Location.relationships.values)
                ),
                EntityDescription(
                    id: FuelProduct.entityName,
                    attributes: FuelProduct.attributes.map { Attribute(id: PropertyKey($0.key), type: $0.value) },
                    relationships: Array(FuelProduct.relationships.values)
                ),
                EntityDescription(
                    id: FuelOption.entityName,
                    attributes: FuelOption.attributes.map { Attribute(id: PropertyKey($0.key), type: $0.value) },
                    relationships: Array(FuelOption.relationships.values)
                )
            ]
        )
    }
}
#endif
