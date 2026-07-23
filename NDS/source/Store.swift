//---------------------------------------------------------------------------------
//
//  Store.swift -- the DS port's CoreModel store.
//
//  The same stack the other front ends use, running as Embedded Swift on the
//  ARM9: `CoreModel.InMemoryStorage` (the synchronous in-memory store, since
//  bare-metal armv5te has no `_Concurrency` runtime for the actor-based
//  `InMemoryModelStorage`) validated against the shared `Model.fueling`
//  schema, holding real `CoreFueling.Location`/`FuelProduct` entities that
//  Network.swift populates from the server. Search runs through the real
//  `Location.Query.search` predicate and CoreModel's pure Swift
//  `FetchRequest` evaluation engine -- not a hand-rolled filter.
//
//---------------------------------------------------------------------------------

import CoreModel
import CoreFueling

/// The in-memory store, shared by the fetch flow and the UI.
let store = InMemoryStorage(model: .fueling)

// MARK: - Queries

/// Locations matching the search text, sorted by name -- the same
/// name/city/directions/address/zip/state predicate the other ports use.
func searchLocations(_ query: [UInt8]) -> [Location] {
  let text = String(decoding: query, as: UTF8.self)
  let request = FetchRequest(
    entity: Location.entityName,
    predicate: Location.Query.search(text)?.predicate
  )
  guard let data = try? store.fetch(request) else { return [] }
  var result = [Location]()
  result.reserveCapacity(data.count)
  for item in data {
    if let location = try? Location(from: item) {
      result.append(location)
    }
  }
  result.sort { utf8Less($0.name, $1.name) }
  return result
}

/// The fuel products linked from a location, sorted by product description.
func fuelProducts(for location: Location) -> [FuelProduct] {
  var result = [FuelProduct]()
  for id in location.fuelProducts {
    guard
      let data = try? store.fetch(FuelProduct.entityName, for: ObjectID(id)),
      let product = try? FuelProduct(from: data)
    else { continue }
    result.append(product)
  }
  result.sort { utf8Less($0.descriptionText, $1.descriptionText) }
  return result
}

// MARK: - Byte helpers

/// String contents as renderer bytes.
func utf8Bytes(_ text: String) -> [UInt8] {
  Array(text.utf8)
}

/// StaticString contents as renderer bytes (fixed labels in menu rows).
func staticBytes(_ text: StaticString) -> [UInt8] {
  text.withUTF8Buffer { buffer -> [UInt8] in
    var bytes = [UInt8]()
    bytes.reserveCapacity(buffer.count)
    for byte in buffer {
      bytes.append(byte)
    }
    return bytes
  }
}

/// Byte-wise lexicographic order (avoids the stdlib's Unicode collation).
func utf8Less(_ a: String, _ b: String) -> Bool {
  var i = a.utf8.makeIterator()
  var j = b.utf8.makeIterator()
  while true {
    switch (i.next(), j.next()) {
    case (nil, nil): return false
    case (nil, _): return true
    case (_, nil): return false
    case (let x?, let y?):
      if x != y { return x < y }
    }
  }
}

/// Decimal integer as bytes (parking-space counts).
func intBytes(_ value: Int32) -> [UInt8] {
  var bytes = [UInt8]()
  var v = value
  if v < 0 {
    bytes.append(45)  // '-'
    v = -v
  }
  var stack = [UInt8]()
  repeat {
    stack.append(UInt8(48 &+ v % 10))
    v /= 10
  } while v > 0
  while let d = stack.popLast() { bytes.append(d) }
  return bytes
}
