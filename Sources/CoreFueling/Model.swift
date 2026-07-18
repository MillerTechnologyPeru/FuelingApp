//
//  Model.swift
//  CoreFueling
//

import CoreModel

public extension Model {

    /// CoreModel schema for the fueling domain.
    static var fueling: Model {
        Model(
            entities:
                Site.self,
            FuelProduct.self,
            FuelOption.self
        )
    }
}
