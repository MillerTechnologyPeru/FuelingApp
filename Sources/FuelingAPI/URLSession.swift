//
//  URLSession.swift
//  FuelingAPI
//

// Excluded on Android and wasm: each supplies its own transport (a JNI-callback
// client in `FuelingAndroid`, a JavaScriptKit `fetch` client in `Web/`), and
// `HTTPTypesFoundation` isn't linked there anyway — on Android it would drag in
// `FoundationNetworking` + its ~42 MB ICU chain, and on wasm `URLSession` has
// no networking backend. The manifest drops the product on both (see
// `urlSessionPlatforms`); the `!os(WASI)` guard keeps this file from importing it.
#if canImport(Foundation) && !os(Android) && !os(WASI)
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import HTTPTypesFoundation

/// `URLSession` is one possible transport; the API itself only depends on
/// ``HTTPClient``. The witness is `URLSession.data(for:)` from
/// `HTTPTypesFoundation`.
extension URLSession: HTTPClient {}
#endif
