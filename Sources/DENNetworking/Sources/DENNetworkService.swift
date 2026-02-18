import Foundation

/// High-level service that executes a `URLRequest`, validates the HTTP status code,
/// and decodes the response body into a `Decodable` type.
public protocol DENNetworkingServiceProtocol {
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T
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
public final class DENNetworkService: DENNetworkingServiceProtocol {

    private let client: DENNetworkHTTPClient
    private let decoder: ResponseDecoder

    public init(client: DENNetworkHTTPClient, decoder: ResponseDecoder = JSONResponseDecoder()) {
        self.client = client
        self.decoder = decoder
    }

    public func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await client.load(request)
        return try decode(data: data, response: response)
    }

    // MARK: - Private

    /// Maps HTTP status codes to `DENNetworkError`, then attempts decoding on 2xx.
    ///
    /// Status code mapping:
    /// - 200-299 → decode response body
    /// - 400 → `.badRequest` with response body as message
    /// - 401 → `.unauthorized`
    /// - 403 → `.forbidden`
    /// - 404 → `.notFound`
    /// - 429 → `.tooManyRequests`
    /// - 401-499 (other) → `.error(statusCode:data:)` for consumer inspection
    /// - 500-599 → `.serverError(statusCode:)`
    private func decode<T: Decodable>(
        data: Data,
        response: HTTPURLResponse
    ) throws -> T {

        switch response.statusCode {
        case 200...299:
            break
        case 400:
            let message = String(data: data, encoding: .utf8) ?? "Bad request"
            throw DENNetworkError.badRequest(message: message)
        case 401:
            throw DENNetworkError.unauthorized
        case 403:
            throw DENNetworkError.forbidden
        case 404:
            throw DENNetworkError.notFound
        case 429:
            throw DENNetworkError.tooManyRequests
        case 400...499:
            throw DENNetworkError.error(statusCode: response.statusCode, data: data)
        case 500...599:
            throw DENNetworkError.serverError(statusCode: response.statusCode)
        default:
            throw DENNetworkError.error(statusCode: response.statusCode, data: data)
        }

        do {
            return try decoder.decode(data)
        } catch let decodingError as DecodingError {
            DENNetworkLogger.debugPrint("\u{274C} DECODING ERROR: \(decodingError)")
            if let bodyString = String(data: data, encoding: .utf8) {
                DENNetworkLogger.debugPrint("--- FAILED TO DECODE THIS ---")
                DENNetworkLogger.debugPrint(bodyString)
                DENNetworkLogger.debugPrint("-----------------------------")
            }
            throw DENNetworkError.decodingError(message: "Failed to parse server response: \(decodingError.localizedDescription)")
        } catch {
            throw DENNetworkError.generic(error.localizedDescription)
        }
    }
}

// MARK: - Response Decoders

/// Abstraction for response body decoding. Implement custom decoders for XML, Protobuf, etc.
public protocol ResponseDecoder {
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
public class JSONResponseDecoder: ResponseDecoder {
    private let jsonDecoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = decoder
    }

    public func decode<T: Decodable>(_ data: Data) throws -> T {
        return try jsonDecoder.decode(T.self, from: data)
    }
}

/// Returns raw `Data` without JSON parsing. Use when `T` is `Data`.
public class RawDataResponseDecoder: ResponseDecoder {
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
