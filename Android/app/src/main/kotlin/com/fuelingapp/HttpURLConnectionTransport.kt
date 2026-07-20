package com.fuelingapp

import com.fuelingapp.jni.AndroidHTTPTransport
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI

/**
 * [AndroidHTTPTransport] implemented with the platform's own
 * [HttpURLConnection], so the shared Swift networking stack works on Android
 * without linking `FoundationNetworking` (and its ICU dependency chain).
 *
 * The Swift side (`AndroidHTTPClient`) calls [send] and the `response*`
 * accessors as one atomic sequence on a single serial queue, so the
 * last-response fields need no synchronization.
 */
class HttpURLConnectionTransport : AndroidHTTPTransport {

    private companion object {
        const val TIMEOUT_MS = 15_000
    }

    private var lastResponseHeaderNames: Array<String> = emptyArray()
    private var lastResponseHeaderValues: Array<String> = emptyArray()
    private var lastResponseBody: ByteArray = ByteArray(0)

    @Throws(IOException::class)
    override fun send(
        method: String,
        url: String,
        headerNames: Array<String>,
        headerValues: Array<String>,
    ): Int {
        val connection = URI(url).toURL().openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            for (i in headerNames.indices) {
                connection.setRequestProperty(headerNames[i], headerValues[i])
            }

            val status = connection.responseCode
            val names = mutableListOf<String>()
            val values = mutableListOf<String>()
            for ((name, headerValueList) in connection.headerFields) {
                // The status line appears as a null-named header; skip it.
                if (name == null) continue
                for (value in headerValueList) {
                    names.add(name)
                    values.add(value)
                }
            }
            lastResponseHeaderNames = names.toTypedArray()
            lastResponseHeaderValues = values.toTypedArray()
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            lastResponseBody = stream?.use { it.readBytes() } ?: ByteArray(0)
            return status
        } finally {
            connection.disconnect()
        }
    }

    override fun responseHeaderNames(): Array<String> = lastResponseHeaderNames

    override fun responseHeaderValues(): Array<String> = lastResponseHeaderValues

    override fun responseBody(): ByteArray = lastResponseBody
}
