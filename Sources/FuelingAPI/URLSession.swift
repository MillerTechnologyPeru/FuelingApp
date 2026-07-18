//
//  URLSession.swift
//  FuelingAPI
//

#if canImport(Foundation)
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
