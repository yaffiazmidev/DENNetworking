import Foundation

/// High-level service that executes a `URLRequest`, validates the HTTP status code,
/// and decodes the response body into a `Decodable` type.
public protocol DENNetworkingServiceProtocol: Sendable {
    func execute<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T
    func execute(_ request: URLRequest) async throws
    func execute<T: Decodable & Sendable>(_ builder: URLRequest.Builder) async throws -> T
    func execute(_ builder: URLRequest.Builder) async throws
}

/// Default implementation of `DENNetworkingServiceProtocol`.
///
/// Responsibilities:
/// 1. Delegates HTTP transport to `DENNetworkHTTPClient`
/// 2. Maps HTTP status codes to `DENNetworkError`
/// 3. Decodes successful responses via `ResponseDecoder`
///
/// Usage:
/// ```swift
/// let decoder = JSONResponseDecoder(decoder: {
///     let d = JSONDecoder()
///     d.keyDecodingStrategy = .convertFromSnakeCase
///     return d
/// }())
/// let service = DENNetworkService(client: httpClient, decoder: decoder)
/// let user: User = try await service.execute(request)
/// ```
public final class DENNetworkService: DENNetworkingServiceProtocol, Sendable {

    private let client: DENNetworkHTTPClient
    private let decoder: ResponseDecoder

    public init(client: DENNetworkHTTPClient, decoder: ResponseDecoder = JSONResponseDecoder()) {
        self.client = client
        self.decoder = decoder
    }

    public func execute<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await client.load(request)
        try validateStatusCode(data: data, response: response)
        return try decodeResponse(data: data)
    }

    /// Executes a request without decoding the response body.
    ///
    /// Use for endpoints that return no content (e.g. DELETE, PUT returning 204).
    public func execute(_ request: URLRequest) async throws {
        let (data, response) = try await client.load(request)
        try validateStatusCode(data: data, response: response)
    }

    /// Executes a request from a builder, decoding the response.
    ///
    /// Shorthand that calls `.build()` for you:
    /// ```swift
    /// let user: User = try await service.execute(
    ///     .url("https://api.example.com/user").method(.GET)
    /// )
    /// ```
    public func execute<T: Decodable & Sendable>(_ builder: URLRequest.Builder) async throws -> T {
        try await execute(builder.build())
    }

    /// Executes a request from a builder without decoding the response body.
    public func execute(_ builder: URLRequest.Builder) async throws {
        try await execute(builder.build())
    }

    // MARK: - Private

    /// Maps HTTP status codes to `DENNetworkError`.
    ///
    /// Status code mapping:
    /// - 200-299 → success
    /// - 400 → `.badRequest` with response body as message
    /// - 401 → `.unauthorized`
    /// - 403 → `.forbidden`
    /// - 404 → `.notFound`
    /// - 408 → `.timeout`
    /// - 429 → `.tooManyRequests`
    /// - Other 4xx → `.httpError(statusCode:data:)` for consumer inspection
    /// - 500-599 → `.serverError(statusCode:)`
    private func validateStatusCode(
        data: Data,
        response: HTTPURLResponse
    ) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 400:
            let message = String(data: data, encoding: .utf8) ?? "Bad request"
            throw DENNetworkError.badRequest(message: message)
        case 401:
            throw DENNetworkError.unauthorized
        case 403:
            throw DENNetworkError.forbidden
        case 404:
            throw DENNetworkError.notFound
        case 408:
            throw DENNetworkError.timeout
        case 429:
            throw DENNetworkError.tooManyRequests
        case 400...499:
            throw DENNetworkError.httpError(statusCode: response.statusCode, data: data)
        case 500...599:
            throw DENNetworkError.serverError(statusCode: response.statusCode)
        default:
            throw DENNetworkError.httpError(statusCode: response.statusCode, data: data)
        }
    }

    private func decodeResponse<T: Decodable>(data: Data) throws -> T {
        do {
            return try decoder.decode(data)
        } catch let decodingError as DecodingError {
            #if DEBUG
            DENNetworkLogger.debugPrint("❌ DECODING ERROR: \(decodingError)")
            if let bodyString = String(data: data, encoding: .utf8) {
                DENNetworkLogger.debugPrint("--- FAILED TO DECODE THIS ---")
                DENNetworkLogger.debugPrint(bodyString)
                DENNetworkLogger.debugPrint("-----------------------------")
            }
            #endif
            throw DENNetworkError.decodingError(message: "Failed to parse server response: \(decodingError.localizedDescription)")
        } catch {
            throw DENNetworkError.generic(error.localizedDescription)
        }
    }
}

// MARK: - Response Decoders

/// Abstraction for response body decoding. Implement custom decoders for XML, Protobuf, etc.
public protocol ResponseDecoder: Sendable {
    func decode<T: Decodable>(_ data: Data) throws -> T
}

/// JSON decoder with configurable `JSONDecoder`.
///
/// Pass a pre-configured decoder for snake_case keys, custom date formats, etc:
/// ```swift
/// let decoder = JSONDecoder()
/// decoder.keyDecodingStrategy = .convertFromSnakeCase
/// decoder.dateDecodingStrategy = .iso8601
/// let responseDecoder = JSONResponseDecoder(decoder: decoder)
/// ```
///
/// - Note: Marked `@unchecked Sendable` because `JSONDecoder` is not formally `Sendable`
///   but is safe when not mutated after initialization. Do not mutate the decoder after passing it in.
public final class JSONResponseDecoder: ResponseDecoder, @unchecked Sendable {
    private let jsonDecoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = decoder
    }

    public func decode<T: Decodable>(_ data: Data) throws -> T {
        return try jsonDecoder.decode(T.self, from: data)
    }
}

/// Returns raw `Data` without JSON parsing. Use when `T` is `Data`.
public final class RawDataResponseDecoder: ResponseDecoder, Sendable {
    public init() { }

    public func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self is Data.Type, let data = data as? T {
            return data
        } else {
            let context = DecodingError.Context(
                codingPath: [],
                debugDescription: "Expected Data type"
            )
            throw DecodingError.typeMismatch(T.self, context)
        }
    }
}
