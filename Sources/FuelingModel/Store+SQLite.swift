//
//  Store+SQLite.swift
//  FuelingModel
//

import CoreModel
import CoreModelSQLite
import SQLite
import CoreFueling

public extension Store {

    /// Build a store backed by a SQLite database file.
    ///
    /// The cross-platform persistence backend — used wherever `CoreDataModel`
    /// is unavailable (Android, Linux), and usable on Darwin too.
    ///
    /// - Parameters:
    ///   - path: File path of the SQLite database (created if it doesn't exist).
    ///   - locationService: Network transport, or `nil` for offline use.
    convenience init(
        sqliteDatabase path: String,
        locationService: (any LocationService)? = nil
    ) throws {
        let storage = try SQLiteDatabase(path: path, model: .fueling)
        let viewContext = try SQLiteViewContext(.uri(path), model: .fueling)
        self.init(
            storage: storage,
            viewContext: viewContext,
            locationService: locationService
        )
    }
}
