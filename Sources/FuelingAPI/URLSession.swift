//
//  URLSession.swift
//  FuelingAPI
//

// Excluded on Android: the app there supplies its own JNI-callback transport
// (see `FuelingAndroid`), and merely linking `HTTPTypesFoundation`'s
// `URLSession` bridge would pull `FoundationNetworking` + its ~42 MB ICU
// dependency chain into every Android build.
#if canImport(Foundation) && !os(Android)
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
