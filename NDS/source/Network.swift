//---------------------------------------------------------------------------------
//
//  Network.swift -- dswifi networking for the DS port.
//
//  Socket flow copied from swift-embedded-nds's wifi_httpget example:
//  associate via the firmware WFC settings (melonDS's firmware points at its
//  emulated "melonAP" access point), open a TCP socket, send a raw HTTP GET,
//  and read until the server closes the connection.
//
//  The server is injected at build time via the FUELING_SERVER_URL
//  environment variable (see tools/gen_server.py), the same variable the
//  playground app and Android port use, defaulting to 10.0.2.2:8080 -- the
//  emulator-NAT alias for the host machine, where Scripts/test-server.py
//  listens. Hostnames are resolved on-device with DNS; nothing is hardcoded
//  anywhere in the sources.
//
//  The JSON walker below is a minimal byte scanner for the API envelope
//  {"status": ..., "message": ..., "data": [...]} in the exact wire format
//  FuelingAPI's GetLocation/FuelPrice DTOs decode on the other platforms --
//  Embedded Swift has no Foundation, so no JSONDecoder. Parsed objects are
//  mapped into `CoreModel.ModelData` mirroring FuelingAPI's ModelData
//  mapping key for key, then inserted into the shared `store` -- with every
//  schema attribute set explicitly (`.null` when absent), since the
//  in-memory store returns records verbatim.
//
//---------------------------------------------------------------------------------

import NDS
import CoreModel
import CoreFueling

// MARK: - Server address
// (serverHost / serverPort / serverHostHeader come from the generated
// ServerConfig.swift -- see tools/gen_server.py.)

/// Resolves the injected host (DNS name or dotted-quad) to an IPv4 address
/// in network byte order, or nil on failure.
func resolveServer() -> UInt32? {
  var hostBytes = staticBytes(serverHost)
  hostBytes.append(0)  // C string terminator
  let resolved: UInt32? = hostBytes.withUnsafeBufferPointer { buffer in
    buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) { name in
      guard let host = gethostbyname(name), let first = host.pointee.h_addr_list[0] else {
        return nil
      }
      return first.withMemoryRebound(to: in_addr_t.self, capacity: 1) { UInt32($0.pointee) }
    }
  }
  return resolved
}

// MARK: - Wifi

var wifiConnected = false

/// Associate using the firmware WFC settings. Blocks until associated or
/// the attempt fails.
func connectWifi() -> Bool {
  if wifiConnected { return true }
  wifiConnected = Wifi_InitDefault(true)  // WFC_CONNECT
  return wifiConnected
}

// MARK: - HTTP

/// host (DS little-endian) -> network byte order. (Macro, doesn't import.)
@inline(__always) func htons(_ x: UInt16) -> UInt16 { x.byteSwapped }

/// Which step of the last HTTP request failed (1 DNS, 2 socket, 3 connect,
/// 4 send, 5 closed-without-data, 6 malformed response) plus the errno and
/// HTTP status -- surfaced on the error screen for debugging.
var lastHTTPStep: Int32 = 0
var lastErrno: Int32 = 0
var lastHTTPStatus: Int32 = 0

/// Raw HTTP GET; returns the response body, or nil on any socket/protocol
/// failure.
func httpGet(path: StaticString) -> [UInt8]? {
  guard let address = resolveServer() else {
    lastHTTPStep = 1
    lastErrno = nds_errno()
    return nil
  }

  let sock = socket(AF_INET, SOCK_STREAM, 0)
  guard sock >= 0 else {
    lastHTTPStep = 2
    lastErrno = nds_errno()
    return nil
  }
  defer { _ = closesocket(sock) }

  var sain = sockaddr_in()
  sain.sin_family = sa_family_t(AF_INET)
  sain.sin_port = htons(serverPort)
  sain.sin_addr.s_addr = address

  let connected = withUnsafePointer(to: &sain) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
      connect(sock, sp, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard connected >= 0 else {
    lastHTTPStep = 3
    lastErrno = nds_errno()
    return nil
  }

  var request = [UInt8]()
  request.append(contentsOf: staticBytes("GET "))
  request.append(contentsOf: staticBytes(path))
  request.append(contentsOf: staticBytes(" HTTP/1.1\r\nHost: "))
  request.append(contentsOf: staticBytes(serverHostHeader))
  request.append(contentsOf: staticBytes("\r\nDevice-ID: 0\r\nConnection: close\r\n\r\n"))
  let sent = request.withUnsafeBytes { send(sock, $0.baseAddress, request.count, 0) }
  guard sent == request.count else {
    lastHTTPStep = 4
    lastErrno = nds_errno()
    return nil
  }

  // Read until the server closes the connection.
  var response = [UInt8]()
  var buffer = [UInt8](repeating: 0, count: 1024)
  while true {
    let received = buffer.withUnsafeMutableBytes { recv(sock, $0.baseAddress, 1024, 0) }
    if received <= 0 { break }
    response.append(contentsOf: buffer[0..<Int(received)])
  }
  _ = shutdown(sock, 0)
  guard !response.isEmpty else {
    lastHTTPStep = 5
    lastErrno = nds_errno()
    return nil
  }

  // "HTTP/1.x NNN ..." -- surface non-2xx statuses distinctly.
  lastHTTPStatus = 0
  if response.count > 12, response[0] == 72 {  // 'H'
    var i = 0
    while i < response.count, response[i] != 32 { i += 1 }  // first space
    var status: Int32 = 0
    i += 1
    while i < response.count, response[i] >= 48, response[i] <= 57 {
      status = status &* 10 &+ Int32(response[i] - 48)
      i += 1
    }
    lastHTTPStatus = status
    guard status >= 200, status < 300 else {
      lastHTTPStep = 6
      lastErrno = 0
      return nil
    }
  }

  // Split headers from body at the first blank line.
  var i = 0
  while i + 3 < response.count {
    if response[i] == 13, response[i + 1] == 10, response[i + 2] == 13, response[i + 3] == 10 {
      return Array(response[(i + 4)...])
    }
    i += 1
  }
  lastHTTPStep = 6
  lastErrno = 0
  return nil
}

// MARK: - JSON scanner

/// Minimal JSON walker over ASCII bytes: strings, numbers, objects, arrays,
/// true/false/null. No Unicode escapes (the wire data is plain ASCII).
struct JSONScanner {
  let bytes: [UInt8]
  var pos = 0

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  var atEnd: Bool { pos >= bytes.count }

  @inline(__always) var current: UInt8 { bytes[pos] }

  mutating func skipWhitespace() {
    while !atEnd, current == 32 || current == 9 || current == 10 || current == 13 {
      pos += 1
    }
  }

  /// Consumes `byte` (after whitespace); false if the next byte differs.
  mutating func consume(_ byte: UInt8) -> Bool {
    skipWhitespace()
    guard !atEnd, current == byte else { return false }
    pos += 1
    return true
  }

  /// Peeks (after whitespace) without consuming.
  mutating func peek() -> UInt8? {
    skipWhitespace()
    return atEnd ? nil : current
  }

  /// Parses a quoted string; assumes the next non-space byte is '"'.
  mutating func parseString() -> [UInt8]? {
    guard consume(34) else { return nil }  // '"'
    var out = [UInt8]()
    while !atEnd {
      let byte = current
      pos += 1
      if byte == 34 { return out }  // closing '"'
      if byte == 92, !atEnd {  // '\'
        let escaped = current
        pos += 1
        switch escaped {
        case 110: out.append(10)  // \n
        case 116: out.append(9)  // \t
        case 114: out.append(13)  // \r
        default: out.append(escaped)  // \" \\ \/ (and anything exotic, verbatim)
        }
      } else {
        out.append(byte)
      }
    }
    return nil
  }

  /// Parses a number (integer or decimal fraction; no exponents in the wire
  /// data) as a Double.
  mutating func parseDouble() -> Double? {
    skipWhitespace()
    var negative = false
    if !atEnd, current == 45 {  // '-'
      negative = true
      pos += 1
    }
    var whole: Int64 = 0
    var sawDigit = false
    while !atEnd, current >= 48, current <= 57 {
      whole = whole &* 10 &+ Int64(current - 48)
      sawDigit = true
      pos += 1
    }
    guard sawDigit else { return nil }
    var fraction: Int64 = 0
    var scale: Int64 = 1
    if !atEnd, current == 46 {  // '.'
      pos += 1
      while !atEnd, current >= 48, current <= 57 {
        if scale < 1_000_000 {
          fraction = fraction &* 10 &+ Int64(current - 48)
          scale &*= 10
        }
        pos += 1
      }
    }
    let value = Double(whole) + Double(fraction) / Double(scale)
    return negative ? -value : value
  }

  /// Skips any single value (string, number, object, array, literal).
  mutating func skipValue() {
    skipWhitespace()
    guard !atEnd else { return }
    switch current {
    case 34:  // string
      _ = parseString()
    case 123, 91:  // '{' or '['
      var depth = 0
      repeat {
        guard !atEnd else { return }
        let byte = current
        if byte == 34 {
          _ = parseString()
          continue
        }
        pos += 1
        if byte == 123 || byte == 91 { depth += 1 }
        if byte == 125 || byte == 93 { depth -= 1 }
      } while depth > 0
    default:  // number / true / false / null
      while !atEnd, current != 44, current != 125, current != 93 {  // , } ]
        pos += 1
      }
    }
  }

  /// Parses an array of strings (the `fueling_options` list).
  mutating func parseStringArray() -> [[UInt8]] {
    var result = [[UInt8]]()
    guard consume(91) else { return result }  // '['
    if peek() == 93 {
      _ = consume(93)
      return result
    }
    repeat {
      if peek() == 34, let value = parseString() {
        result.append(value)
      } else {
        skipValue()
      }
    } while consume(44)  // ','
    _ = consume(93)  // ']'
    return result
  }
}

/// Byte-array key comparison against a fixed name.
func isKey(_ key: [UInt8], _ name: StaticString) -> Bool {
  name.withUTF8Buffer { buffer -> Bool in
    guard buffer.count == key.count else { return false }
    var i = 0
    while i < key.count {
      if key[i] != buffer[i] { return false }
      i += 1
    }
    return true
  }
}

// MARK: - Wire parsing

/// Walks the `{"status", "message", "data": [...]}` envelope; calls
/// `element` positioned at each element of the `data` array.
private func parseEnvelope(_ body: [UInt8], element: (inout JSONScanner) -> Void) -> Bool {
  var scanner = JSONScanner(body)
  guard scanner.consume(123) else { return false }  // '{'
  while true {
    guard let key = scanner.parseString() else { return false }
    guard scanner.consume(58) else { return false }  // ':'
    if isKey(key, "data") {
      guard scanner.consume(91) else { return false }  // '['
      if scanner.peek() == 93 {  // empty array
        _ = scanner.consume(93)
      } else {
        repeat {
          element(&scanner)
        } while scanner.consume(44)  // ','
        guard scanner.consume(93) else { return false }  // ']'
      }
    } else {
      scanner.skipValue()
    }
    if !scanner.consume(44) { break }  // ','
  }
  return true
}

/// A parsed location: its entity data plus the join key for fuel prices.
private struct LocationRecord {
  var id: Location.ID
  var data: ModelData
  var fuelProductIDs: [ObjectID] = []
}

/// The moment data was cached. The DS port has no calendar clock wired up;
/// the epoch marks every record as stale, which is harmless offline.
private var cachedDate: AttributeValue { .date(Date(timeIntervalSince1970: 0)) }

/// GET /v1/locations -> location + fuel option records, mirroring
/// FuelingAPI's `ModelData(location:)` mapping (every schema attribute is
/// set explicitly -- see the header note).
private func parseLocations(_ body: [UInt8]) -> (locations: [LocationRecord], options: [ModelData])? {
  var records = [LocationRecord]()
  var options = [ModelData]()
  let ok = parseEnvelope(body) { scanner in
    var id: Location.ID?
    var name = "", address = "", city = "", state = "", zipCode = "", phone = ""
    var brand: String?, directions: String?
    var latitude = 0.0, longitude = 0.0
    var fuelLanes: Int16 = 0, parking: Int16 = 0, showers: Int16 = 0
    var fuelingOptions = [[UInt8]]()

    guard scanner.consume(123) else { return }  // '{'
    while true {
      guard let key = scanner.parseString(), scanner.consume(58) else { break }
      if isKey(key, "site_id") {
        let raw = scanner.parseString() ?? []
        id = Location.ID.Prefixed(rawValue: String(decoding: raw, as: UTF8.self)).map { Location.ID($0) }
      } else if isKey(key, "location_name") {
        name = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "address_line_1") {
        address = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "city") {
        city = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "state") {
        state = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "zip_code") {
        zipCode = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "store_brand") {
        if scanner.peek() == 34 {
          brand = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
        } else {
          scanner.skipValue()
        }
      } else if isKey(key, "directions") {
        if scanner.peek() == 34 {
          directions = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
        } else {
          scanner.skipValue()
        }
      } else if isKey(key, "latitude") {
        latitude = scanner.parseDouble() ?? 0
      } else if isKey(key, "longitude") {
        longitude = scanner.parseDouble() ?? 0
      } else if isKey(key, "diesel_dispenser_lanes") {
        fuelLanes = Int16(scanner.parseDouble() ?? 0)
      } else if isKey(key, "truck_parking_spaces") {
        parking = Int16(scanner.parseDouble() ?? 0)
      } else if isKey(key, "private_showers") {
        showers = Int16(scanner.parseDouble() ?? 0)
      } else if isKey(key, "fueling_options") {
        fuelingOptions = scanner.parseStringArray()
      } else if isKey(key, "phone_numbers") {
        // nested object; pull the primary number
        if scanner.consume(123) {
          while true {
            guard let inner = scanner.parseString(), scanner.consume(58) else { break }
            if isKey(inner, "primary_phone_number") {
              phone = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
            } else {
              scanner.skipValue()
            }
            if !scanner.consume(44) { break }
          }
          _ = scanner.consume(125)  // '}'
        }
      } else {
        scanner.skipValue()
      }
      if !scanner.consume(44) { break }
    }
    _ = scanner.consume(125)  // '}'
    guard let id else { return }

    // fuel options -> entities + relationship ids
    var optionIDs = [ObjectID]()
    for optionName in fuelingOptions {
      let text = String(decoding: optionName, as: UTF8.self)
      guard let optionID = FuelOption.ID(name: text) else { continue }
      optionIDs.append(ObjectID(optionID))
      var option = ModelData(entity: FuelOption.entityName, id: ObjectID(optionID))
      option.attributes[.init(FuelOption.CodingKeys.name)] = .string(text)
      option.relationships[.init(FuelOption.CodingKeys.locations)] = .toMany([])
      options.append(option)
    }

    var data = ModelData(entity: Location.entityName, id: ObjectID(id))
    data.attributes[.init(Location.CodingKeys.name)] = .string(name)
    data.attributes[.init(Location.CodingKeys.brand)] = brand.map { .string($0) } ?? .null
    data.attributes[.init(Location.CodingKeys.address)] = .string(address)
    data.attributes[.init(Location.CodingKeys.city)] = .string(city)
    data.attributes[.init(Location.CodingKeys.state)] = .string(state)
    data.attributes[.init(Location.CodingKeys.zipCode)] = .string(zipCode)
    data.attributes[.init(Location.CodingKeys.phone)] = .string(phone)
    data.attributes[.init(Location.CodingKeys.directions)] = directions.map { .string($0) } ?? .null
    data.attributes[.init(Location.CodingKeys.latitude)] = .double(latitude)
    data.attributes[.init(Location.CodingKeys.longitude)] = .double(longitude)
    data.attributes[.init(Location.CodingKeys.fuelLanes)] = .int16(fuelLanes)
    data.attributes[.init(Location.CodingKeys.truckParkingSpaces)] = .int16(parking)
    data.attributes[.init(Location.CodingKeys.showers)] = .int16(showers)
    data.attributes[.init(Location.CodingKeys.lastCached)] = cachedDate
    data.attributes[.init(Location.CodingKeys.lastViewed)] = .null
    data.relationships[.init(Location.CodingKeys.fuelOptions)] = .toMany(optionIDs)
    records.append(LocationRecord(id: id, data: data))
  }
  return ok ? (records, options) : nil
}

/// GET /v1/fuelprice -> fuel product records, mirroring FuelingAPI's
/// `ModelData(fuelPrice:)` mapping, appended to the owning location's
/// `fuelProducts` join list.
private func parseFuelPrices(_ body: [UInt8], into records: inout [LocationRecord]) -> [ModelData] {
  var products = [ModelData]()
  _ = parseEnvelope(body) { scanner in
    var locationID: Location.ID?
    var fuelCode = ""
    var description = ""
    var price = 0.0
    guard scanner.consume(123) else { return }  // '{'
    while true {
      guard let key = scanner.parseString(), scanner.consume(58) else { break }
      if isKey(key, "siteID") {
        let raw = scanner.parseString() ?? []
        locationID = Location.ID.Prefixed(rawValue: String(decoding: raw, as: UTF8.self)).map { Location.ID($0) }
      } else if isKey(key, "fuelCode") {
        fuelCode = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "productDescription") {
        description = String(decoding: scanner.parseString() ?? [], as: UTF8.self)
      } else if isKey(key, "price") {
        price = scanner.parseDouble() ?? 0
      } else {
        scanner.skipValue()
      }
      if !scanner.consume(44) { break }
    }
    _ = scanner.consume(125)  // '}'
    guard let locationID, !description.isEmpty else { return }

    let productID = FuelProduct.ID.fuelPrice(fuelCode, location: locationID)
    var data = ModelData(entity: FuelProduct.entityName, id: ObjectID(productID))
    data.attributes[.init(FuelProduct.CodingKeys.updated)] = cachedDate
    data.attributes[.init(FuelProduct.CodingKeys.price)] = .double(price)
    data.attributes[.init(FuelProduct.CodingKeys.descriptionText)] = .string(description)
    data.attributes[.init(FuelProduct.CodingKeys.lastCached)] = cachedDate
    data.relationships[.init(FuelProduct.CodingKeys.location)] = .toOne(ObjectID(locationID))
    products.append(data)

    var index = 0
    while index < records.count {
      if records[index].id == locationID {
        records[index].fuelProductIDs.append(ObjectID(productID))
        break
      }
      index += 1
    }
  }
  return products
}

// MARK: - Fetch flow

enum FetchResult {
  case success
  case wifiFailed
  case requestFailed
  case parseFailed
  case storeFailed
}

/// Connects (once), downloads locations + fuel prices, and populates the
/// shared CoreModel store.
func fetchAll() -> FetchResult {
  guard connectWifi() else { return .wifiFailed }
  guard let locationsBody = httpGet(path: "/v1/locations") else { return .requestFailed }
  guard var (records, options) = parseLocations(locationsBody), !records.isEmpty else {
    return .parseFailed
  }
  // Prices are optional -- show locations even if this request fails,
  // like the other ports do.
  var products = [ModelData]()
  if let pricesBody = httpGet(path: "/v1/fuelprice") {
    products = parseFuelPrices(pricesBody, into: &records)
  }
  do {
    for option in options {
      try store.insert(option)
    }
    for product in products {
      try store.insert(product)
    }
    for var record in records {
      // The in-memory store returns records verbatim (no inverse
      // relationship maintenance), so the join list is set explicitly.
      record.data.relationships[.init(Location.CodingKeys.fuelProducts)] = .toMany(record.fuelProductIDs)
      try store.insert(record.data)
    }
  } catch {
    return .storeFailed
  }
  return .success
}
