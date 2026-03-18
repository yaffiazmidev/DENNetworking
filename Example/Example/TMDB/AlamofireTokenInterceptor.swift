import Foundation
import Alamofire
import DENNetworking

/// Alamofire-native token refresh using `RequestInterceptor`.
///
/// This integrates directly with Alamofire's retry pipeline — the Alamofire way
/// to handle token refresh, as opposed to using `AuthenticatedHTTPClientDecorator`.
///
/// **When to use which:**
/// - `AlamofireTokenInterceptor` — when using Alamofire as transport. Leverages Alamofire's
///   built-in retry/adapt pipeline, certificate pinning, and event monitors.
/// - `AuthenticatedHTTPClientDecorator` — when using URLSession or when you want transport-agnostic
///   auth handling via the DENNetworking decorator pattern.
///
/// ## Usage
/// ```swift
/// let tokenStore = KeychainTokenStore()
/// let interceptor = AlamofireTokenInterceptor(
///     tokenStore: tokenStore,
///     refreshURL: URL(string: "https://api.example.com/auth/refresh")!
/// )
/// let session = Session(interceptor: interceptor)
/// let client = AlamofireHTTPClient(session: session)
/// let service = DENNetworkService(client: client)
/// ```
final class AlamofireTokenInterceptor: RequestInterceptor, @unchecked Sendable {

    private let tokenStore: AlamofireTokenStore
    private let refreshURL: URL
    private let tokenHeaderKey: String
    private let tokenPrefix: String
    private let maxRetryCount: Int

    private let lock = NSLock()
    private var isRefreshing = false
    private var requestsToRetry: [(RetryResult) -> Void] = []

    /// Creates a token interceptor.
    ///
    /// - Parameters:
    ///   - tokenStore: Provides and persists tokens.
    ///   - refreshURL: The endpoint to call for token refresh.
    ///   - tokenHeaderKey: Header key for the token (default: `"Authorization"`).
    ///   - tokenPrefix: Prefix before the token value (default: `"Bearer "`).
    ///   - maxRetryCount: Maximum retry attempts per request (default: 1).
    init(
        tokenStore: AlamofireTokenStore,
        refreshURL: URL,
        tokenHeaderKey: String = "Authorization",
        tokenPrefix: String = "Bearer ",
        maxRetryCount: Int = 1
    ) {
        self.tokenStore = tokenStore
        self.refreshURL = refreshURL
        self.tokenHeaderKey = tokenHeaderKey
        self.tokenPrefix = tokenPrefix
        self.maxRetryCount = maxRetryCount
    }

    // MARK: - RequestAdapter

    /// Injects the current access token into every outgoing request.
    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var request = urlRequest

        guard let token = tokenStore.accessToken, !token.isEmpty else {
            completion(.success(request))
            return
        }

        request.setValue(tokenPrefix + token, forHTTPHeaderField: tokenHeaderKey)
        completion(.success(request))
    }

    // MARK: - RequestRetrier

    /// Handles 401 responses by refreshing the token and retrying the request.
    ///
    /// When multiple requests receive 401 concurrently:
    /// 1. First request triggers the refresh
    /// 2. Subsequent requests queue up and wait
    /// 3. After refresh completes, all queued requests retry with the new token
    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard let response = request.task?.response as? HTTPURLResponse,
              response.statusCode == 401,
              request.retryCount < maxRetryCount else {
            completion(.doNotRetry)
            return
        }

        lock.lock()
        requestsToRetry.append(completion)

        if isRefreshing {
            // Another request is already refreshing — wait for it
            lock.unlock()
            return
        }

        isRefreshing = true
        lock.unlock()

        refreshToken(session: session)
    }

    // MARK: - Token Refresh

    private func refreshToken(session: Session) {
        guard let refreshToken = tokenStore.refreshToken else {
            completeAllRequests(with: .doNotRetry)
            return
        }

        // Build refresh request
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RefreshRequestBody(refreshToken: refreshToken)
        request.httpBody = try? JSONEncoder().encode(body)

        // Use a separate session to avoid interceptor recursion
        let plainSession = URLSession.shared
        let task = plainSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            defer { self.lock.lock(); self.isRefreshing = false; self.lock.unlock() }

            guard let data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let tokenResponse = try? JSONDecoder().decode(RefreshResponseBody.self, from: data) else {
                // Refresh failed — don't retry any requests
                self.completeAllRequests(with: .doNotRetry)
                return
            }

            // Store new tokens
            self.tokenStore.update(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )

            // Retry all queued requests with the new token
            self.completeAllRequests(with: .retry)
        }

        task.resume()
    }

    private func completeAllRequests(with result: RetryResult) {
        lock.lock()
        let completions = requestsToRetry
        requestsToRetry.removeAll()
        lock.unlock()

        completions.forEach { $0(result) }
    }
}

// MARK: - Token Store Protocol

/// Protocol for persisting access and refresh tokens.
///
/// Implement this with your storage backend (Keychain, UserDefaults for dev, etc.):
/// ```swift
/// final class KeychainTokenStore: AlamofireTokenStore {
///     var accessToken: String? {
///         get { try? KeychainService.load(key: "access_token") }
///         set { ... }
///     }
///     var refreshToken: String? {
///         get { try? KeychainService.load(key: "refresh_token") }
///         set { ... }
///     }
///     func update(accessToken: String, refreshToken: String?) { ... }
///     func clear() { ... }
/// }
/// ```
protocol AlamofireTokenStore: AnyObject, Sendable {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func update(accessToken: String, refreshToken: String?)
    func clear()
}

// MARK: - In-Memory Token Store (for demo/testing)

/// Simple in-memory token store. Use `KeychainTokenStore` in production.
final class InMemoryTokenStore: AlamofireTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _accessToken: String?
    private var _refreshToken: String?

    var accessToken: String? { lock.withLock { _accessToken } }
    var refreshToken: String? { lock.withLock { _refreshToken } }

    init(accessToken: String? = nil, refreshToken: String? = nil) {
        _accessToken = accessToken
        _refreshToken = refreshToken
    }

    func update(accessToken: String, refreshToken: String?) {
        lock.withLock {
            _accessToken = accessToken
            if let refreshToken { _refreshToken = refreshToken }
        }
    }

    func clear() {
        lock.withLock {
            _accessToken = nil
            _refreshToken = nil
        }
    }
}

// MARK: - Request/Response Bodies

private struct RefreshRequestBody: Encodable {
    let refreshToken: String
}

private struct RefreshResponseBody: Decodable {
    let accessToken: String
    let refreshToken: String?
}
