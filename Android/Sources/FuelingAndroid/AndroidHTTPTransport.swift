//
//  AndroidHTTPTransport.swift
//  FuelingAndroid
//
//  JNI callback protocol implemented in Kotlin/Java via swift-java
//  (`enableJavaCallbacks`).
//

/// Flattened, synchronous HTTP transport implemented on the Java/Kotlin side
/// (e.g. with `HttpURLConnection`), so the shared Swift networking stack can
/// run on Android without linking `FoundationNetworking` (and its ~42 MB ICU
/// dependency chain).
///
/// This is deliberately **not** ``FuelingAPI/HTTPClient``: swift-java's JNI
/// callback bridging supports only synchronous, untyped-`throws` methods whose
/// parameters and returns are primitives, `String`, and arrays of those — no
/// `associatedtype`, typed throws, `async`, or custom structs. See
/// ``AndroidHTTPClient`` for the adapter that bridges this into the real
/// `HTTPClient` protocol.
///
/// ## Threading and reentrancy
/// ``AndroidHTTPClient`` invokes ``send(method:url:headerNames:headerValues:)``
/// and the `response*()` accessors as one atomic sequence on a single serial
/// queue, so implementations may store the most recent response in plain
/// instance fields without synchronization — but must not assume any
/// *particular* thread (only that calls never interleave).
public protocol AndroidHTTPTransport {

    /// Perform the request synchronously and return the HTTP status code.
    ///
    /// `headerNames`/`headerValues` are parallel arrays (JNI callbacks cannot
    /// bridge dictionaries). Throw only for transport-level failures
    /// (connection refused, timeout, malformed URL) — HTTP error statuses are
    /// returned normally as the status code.
    func send(
        method: String,
        url: String,
        headerNames: [String],
        headerValues: [String]
    ) throws -> Int32

    /// Response header names from the most recently completed ``send``,
    /// parallel to ``responseHeaderValues()``.
    func responseHeaderNames() -> [String]

    /// Response header values from the most recently completed ``send``,
    /// parallel to ``responseHeaderNames()``.
    func responseHeaderValues() -> [String]

    /// Response body bytes from the most recently completed ``send``.
    ///
    /// `Int8` rather than `UInt8`: Java's `byte` is signed, and jextract's
    /// callback wrapper fails to compile for `[UInt8]` returns.
    func responseBody() -> [Int8]
}
