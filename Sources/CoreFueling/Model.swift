//
//  Model.swift
//  CoreFueling
//

import CoreModel

// Not available under Embedded Swift: `EntityDescription(entity:)` and the
// `Relationship(id:entity:destination:type:inverseRelationship:)` convenience
// initializer it relies on both require `T: CoreModel.Entity`, and the
// Embedded-only declarations of `Location`/`FuelProduct`/`FuelOption` (see the
// note atop Location.swift) don't conform — nothing under Embedded consumes a
// `Model` schema yet, since CoreModel's generic `Entity`-based `ModelStorage`
// helpers are themselves unavailable there.
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
#endif
