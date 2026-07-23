//
//  FetchHTTPClient.swift
//  FuelingWeb
//

import JavaScriptKit
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FuelingAPI

/// An ``HTTPClient`` transport backed by the browser `fetch` API through
/// JavaScriptKit.
///
/// The wasm counterpart to `URLSession` (Apple/Linux) and the JNI-callback
/// client (Android): the API layer only speaks ``HTTPClient``, so wiring a
/// `fetch`-based transport is all it takes to run the same networking code in
/// the browser.
///
/// Requires `JavaScriptEventLoop.installGlobalExecutor()` to have run so the
/// `await`s on JS promises resume on the single browser thread.
public struct FetchHTTPClient: HTTPClient {

    public enum Failure: Swift.Error {
        /// The request lacked a scheme/authority/path, so no absolute URL could be built.
        case invalidRequestURL
        /// `fetch` resolved to something that wasn't a `Response` object.
        case notAResponse
        /// The underlying `fetch`/`arrayBuffer` promise rejected.
        case javaScript(JSException)
    }

    public init() {}

    public func data(
        for request: HTTPRequest
    ) async throws(Failure) -> (Data, HTTPResponse) {
        guard
            let scheme = request.scheme,
            let authority = request.authority,
            let path = request.path
        else {
            throw .invalidRequestURL
        }
        let url = "\(scheme)://\(authority)\(path)"

        // Build the `fetch(url, { method, headers })` init dictionary.
        let headers = JSObject()
        for field in request.headerFields {
            headers[field.name.canonicalName] = .string(field.value)
        }
        let options = JSObject()
        options["method"] = .string(request.method.rawValue)
        options["headers"] = .object(headers)

        let fetch = JSObject.global.fetch.function!
        do {
            let responseValue = try await JSPromise(
                unsafelyWrapping: fetch(url, options).object!
            ).value
            guard let response = responseValue.object else {
                throw Failure.notAResponse
            }
            let statusCode = Int(response.status.number ?? 0)

            // response.arrayBuffer() -> Promise<ArrayBuffer> -> Uint8Array -> Data
            let bufferValue = try await JSPromise(
                unsafelyWrapping: response.arrayBuffer!().object!
            ).value
            let byteArray = JSObject.global.Uint8Array.function!.new(bufferValue)
            let bytes = JSTypedArray<UInt8>(unsafelyWrapping: byteArray)
            let data = bytes.withUnsafeBytes { Data(buffer: $0) }

            return (data, HTTPResponse(status: .init(code: statusCode)))
        } catch let error as JSException {
            throw .javaScript(error)
        } catch let error as Failure {
            throw error
        } catch {
            throw .notAResponse
        }
    }
}
