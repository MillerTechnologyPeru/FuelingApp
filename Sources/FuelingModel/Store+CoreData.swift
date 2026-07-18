//
//  Store+CoreData.swift
//  FuelingModel
//

#if canImport(CoreData)
import Foundation
import CoreData
import CoreModel
import CoreDataModel
import CoreFueling

public extension Store {

    /// Build a store backed by a CoreData persistent container.
    ///
    /// - Parameters:
    ///   - name: Name of the persistent container.
    ///   - siteService: Network transport, or `nil` for offline use.
    ///   - isStoredInMemoryOnly: Use a transient in-memory store (previews, playgrounds, tests).
    convenience init(
        named name: String = "Fueling",
        siteService: (any SiteService)? = nil,
        isStoredInMemoryOnly: Bool = false
    ) throws {
        var storeDescriptions = [NSPersistentStoreDescription]()
        if isStoredInMemoryOnly {
            let description = NSPersistentStoreDescription(
                url: URL(fileURLWithPath: "/dev/null")
            )
            storeDescriptions.append(description)
        }
        let storage = PersistentContainerStorage(
            name: name,
            model: .fueling,
            storeDescriptions: storeDescriptions
        )
        self.init(
            storage: storage,
            viewContext: try storage.viewContext,
            siteService: siteService
        )
    }
}
#endif
