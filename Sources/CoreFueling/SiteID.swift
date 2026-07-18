//
//  SiteID.swift
//  CoreFueling
//

public extension Site {

    /// Site Identifier
    struct ID: RawRepresentable, Codable, Equatable, Hashable, Sendable {

        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Site.ID: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt) {
        self.init(rawValue: value)
    }
}

// MARK: - CustomStringConvertible

extension Site.ID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        rawValue.description
    }
}

// MARK: - Supporting Types

public extension Site.ID {

    /// Site identifier in its zero-padded 4-digit wire format.
    struct Prefixed: Codable, Equatable, Hashable, Sendable {

        internal let value: Site.ID.RawValue

        internal init(_ value: Site.ID.RawValue) {
            self.value = value
        }

        public init(id: Site.ID) {
            self.value = id.rawValue
        }
    }
}

public extension Site.ID {

    init(_ prefixed: Prefixed) {
        self.init(rawValue: prefixed.value)
    }
}

// MARK: - RawRepresentable

extension Site.ID.Prefixed: RawRepresentable {

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

extension Site.ID.Prefixed: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: UInt) {
        self.init(value)
    }
}

// MARK: - CustomStringConvertible

extension Site.ID.Prefixed: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        rawValue.description
    }

    public var debugDescription: String {
        rawValue.description
    }
}
