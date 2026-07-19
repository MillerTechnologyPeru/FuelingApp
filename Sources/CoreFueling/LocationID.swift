//
//  LocationID.swift
//  CoreFueling
//

public extension Location {

    /// Location Identifier
    struct ID: RawRepresentable, Equatable, Hashable, Sendable {

        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
}

// Codable relies on stdlib synthesis, which is unavailable under Embedded Swift.
#if !hasFeature(Embedded)
extension Location.ID: Codable {}
#endif

// MARK: - ExpressibleByIntegerLiteral

extension Location.ID: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension Location.ID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        rawValue.description
    }
}

// MARK: - Supporting Types

public extension Location.ID {

    /// Location identifier in its zero-padded 4-digit wire format.
    struct Prefixed: Equatable, Hashable, Sendable {

        internal let value: Location.ID.RawValue

        internal init(_ value: Location.ID.RawValue) {
            self.value = value
        }

        public init(id: Location.ID) {
            self.value = id.rawValue
        }
    }
}

// Codable relies on stdlib synthesis, which is unavailable under Embedded Swift.
#if !hasFeature(Embedded)
extension Location.ID.Prefixed: Codable {}
#endif

public extension Location.ID {

    init(_ prefixed: Prefixed) {
        self.init(rawValue: prefixed.value)
    }
}

// MARK: - RawRepresentable

extension Location.ID.Prefixed: RawRepresentable {

    public init?(rawValue: String) {
        guard let id = UInt(rawValue) else { return nil }
        self.init(id)
    }

    public var rawValue: String {
        // zero-padded 4 digit string value
        var string = value.description
        while string.count < 4 {
            string = "0" + string
        }
        return string
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Location.ID.Prefixed: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt) {
        self.init(value)
    }
}

// MARK: - CustomStringConvertible

extension Location.ID.Prefixed: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        rawValue.description
    }
}
