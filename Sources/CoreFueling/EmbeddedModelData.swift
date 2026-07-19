//
//  EmbeddedModelData.swift
//  CoreFueling
//

#if hasFeature(Embedded)
import CoreModel

// CoreModel's own generic `ModelData.decode`/`decodeRelationship` helpers (in
// `Decodable.swift`) are declared as plain `throws`, which under Embedded Swift
// implicitly boxes the concrete `CoreModelError` they throw into `any Error` —
// disallowed there (`cannot use a value of protocol type 'any Error' in
// embedded Swift`). These typed-throws (`throws(CoreModelError)`) equivalents
// read `ModelData.attributes`/`relationships` directly instead, so the hand-
// written `init(from:)`/`encode()` implementations below never call into that
// broken generic path.

internal extension ModelData {

    func attribute(forKey key: some CodingKey) throws(CoreModelError) -> AttributeValue {
        let property = PropertyKey(key)
        guard let value = attributes[property] else {
            throw CoreModelError.keyNotFound(property)
        }
        return value
    }

    func string(forKey key: some CodingKey) throws(CoreModelError) -> String {
        guard case .string(let value) = try attribute(forKey: key) else {
            throw CoreModelError.typeMismatch(PropertyKey(key))
        }
        return value
    }

    func optionalString(forKey key: some CodingKey) throws(CoreModelError) -> String? {
        switch try attribute(forKey: key) {
        case .null: return nil
        case .string(let value): return value
        default: throw CoreModelError.typeMismatch(PropertyKey(key))
        }
    }

    func double(forKey key: some CodingKey) throws(CoreModelError) -> Double {
        guard case .double(let value) = try attribute(forKey: key) else {
            throw CoreModelError.typeMismatch(PropertyKey(key))
        }
        return value
    }

    func int16(forKey key: some CodingKey) throws(CoreModelError) -> Int {
        guard case .int16(let value) = try attribute(forKey: key) else {
            throw CoreModelError.typeMismatch(PropertyKey(key))
        }
        return Int(value)
    }

    func date(forKey key: some CodingKey) throws(CoreModelError) -> Date {
        guard case .date(let value) = try attribute(forKey: key) else {
            throw CoreModelError.typeMismatch(PropertyKey(key))
        }
        return value
    }

    func optionalDate(forKey key: some CodingKey) throws(CoreModelError) -> Date? {
        switch try attribute(forKey: key) {
        case .null: return nil
        case .date(let value): return value
        default: throw CoreModelError.typeMismatch(PropertyKey(key))
        }
    }

    func toOne<T: ObjectIDConvertible>(_ type: T.Type, forKey key: some CodingKey) throws(CoreModelError) -> T {
        let property = PropertyKey(key)
        guard let relationship = relationships[property] else {
            throw CoreModelError.keyNotFound(property)
        }
        guard case .toOne(let objectID) = relationship else {
            throw CoreModelError.typeMismatch(property)
        }
        guard let id = T(objectID: objectID) else {
            throw CoreModelError.invalidIdentifier(objectID)
        }
        return id
    }

    func toMany<T: ObjectIDConvertible>(_ type: T.Type, forKey key: some CodingKey) throws(CoreModelError) -> [T] {
        let property = PropertyKey(key)
        guard let relationship = relationships[property] else {
            return []
        }
        switch relationship {
        case .null:
            return []
        case .toOne:
            throw CoreModelError.typeMismatch(property)
        case .toMany(let objectIDs):
            var result = [T]()
            result.reserveCapacity(objectIDs.count)
            for objectID in objectIDs {
                guard let id = T(objectID: objectID) else {
                    throw CoreModelError.invalidIdentifier(objectID)
                }
                result.append(id)
            }
            return result
        }
    }

    mutating func encode(_ value: String, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = .string(value)
    }

    mutating func encode(_ value: String?, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = value.map { .string($0) } ?? .null
    }

    mutating func encode(_ value: Double, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = .double(value)
    }

    mutating func encodeInt16(_ value: Int, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = .int16(Int16(value))
    }

    mutating func encode(_ value: Date, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = .date(value)
    }

    mutating func encode(_ value: Date?, forKey key: some CodingKey) {
        attributes[PropertyKey(key)] = value.map { .date($0) } ?? .null
    }

    mutating func encodeToOne(_ value: some CustomStringConvertible, forKey key: some CodingKey) {
        relationships[PropertyKey(key)] = .toOne(ObjectID(rawValue: value.description))
    }

    mutating func encodeToMany(_ values: [some CustomStringConvertible], forKey key: some CodingKey) {
        relationships[PropertyKey(key)] = .toMany(values.map { ObjectID(rawValue: $0.description) })
    }
}
#endif
