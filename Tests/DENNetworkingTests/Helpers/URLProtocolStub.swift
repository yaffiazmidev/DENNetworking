import Foundation

/// A `URLProtocol` subclass used to intercept and stub `URLSession` requests in integration tests.
///
/// Usage:
/// ```swift
/// URLProtocolStub.stub(data: someData, response: httpResponse, error: nil)
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [URLProtocolStub.self]
/// let session = URLSession(configuration: config)
/// ```
final class URLProtocolStub: URLProtocol {

    // MARK: - Stub State

    private static var stubbedData: Data?
    private static var stubbedResponse: URLResponse?
    private static var stubbedError: Error?

    /// Configures the stub to return the given data, response, and/or error for any intercepted request.
    static func stub(data: Data?, response: URLResponse?, error: Error?) {
        stubbedData = data
        stubbedResponse = response
        stubbedError = error
    }

    /// Resets all stub state. Call this in `tearDown` to prevent test pollution.
    static func clean() {
        stubbedData = nil
        stubbedResponse = nil
        stubbedError = nil
    }

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let response = URLProtocolStub.stubbedResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = URLProtocolStub.stubbedData {
            client?.urlProtocol(self, didLoad: data)
        }

        if let error = URLProtocolStub.stubbedError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
