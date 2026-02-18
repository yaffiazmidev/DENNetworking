import Foundation

/// Low-level HTTP transport abstraction.
///
/// Implementations are responsible only for sending a `URLRequest` and returning raw `(Data, HTTPURLResponse)`.
/// Status code interpretation and decoding happen at the `DENNetworkService` layer.
///
/// Designed for the **Decorator pattern** — wrap implementations to add cross-cutting concerns:
/// ```
/// URLSession/Alamofire → TokenRefresh → Authenticated → Retry → DENNetworkService
/// ```
///
/// Built-in conformers:
/// - `DENNetworkURLSessionHTTPClient` — URLSession-based (this module)
/// - `AuthenticatedHTTPClientDecorator` — injects base URL, headers, and query params (DENCryptoCore)
/// - `RetryHTTPClientDecorator` — automatic retry on retryable errors (DENCryptoCore)
public protocol DENNetworkHTTPClient: Sendable {
    /// Executes an HTTP request and returns raw response data.
    ///
    /// - Note: This method does **not** validate status codes. It returns any successful HTTP response
    ///   (including 4xx/5xx). Status code handling is done by `DENNetworkService.decode()`.
    /// - Throws: `DENNetworkError` for transport-level failures (no connection, timeout, cancelled).
    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
