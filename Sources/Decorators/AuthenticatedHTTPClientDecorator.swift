import Foundation

/// Provider that supplies authentication tokens.
///
/// Implement this protocol to integrate with your app's auth system:
/// ```swift
/// final class MyTokenProvider: TokenProvider {
///     func currentToken() async throws -> String {
///         return keychain.get("access_token") ?? ""
///     }
///
///     func refreshToken() async throws -> String {
///         let newToken = try await authService.refresh()
///         keychain.set(newToken, forKey: "access_token")
///         return newToken
///     }
/// }
/// ```
public protocol TokenProvider: Sendable {
    /// Returns the current authentication token.
    func currentToken() async throws -> String

    /// Refreshes and returns a new token. Called after receiving a 401 response.
    func refreshToken() async throws -> String
}

/// Decorator that injects base URL, authentication headers, and common query parameters.
///
/// Optionally handles 401 responses by refreshing the token and retrying once.
/// When multiple concurrent requests receive 401, only one token refresh is performed —
/// all other requests wait for the same refresh result.
///
/// Usage:
/// ```swift
/// let client = DENNetworkURLSessionHTTPClient()
/// let auth = AuthenticatedHTTPClientDecorator(
///     decoratee: client,
///     baseURL: URL(string: "https://api.example.com")!,
///     tokenProvider: myTokenProvider,
///     commonHeaders: ["Accept": "application/json"]
/// )
/// let service = DENNetworkService(client: auth)
/// ```
///
/// Compose with `URLRequest.path()` for relative URLs:
/// ```swift
/// let request = try URLRequest.path("v1/users").method(.GET).build()
/// // AuthenticatedHTTPClientDecorator prepends "https://api.example.com"
/// // and injects "Authorization: Bearer <token>" header
/// ```
public final class AuthenticatedHTTPClientDecorator: DENNetworkHTTPClient, Sendable {

    private let decoratee: DENNetworkHTTPClient
    private let baseURL: URL?
    private let tokenProvider: TokenProvider?
    private let tokenHeaderKey: String
    private let tokenPrefix: String
    private let commonHeaders: [String: String]
    private let commonQueryParameters: [String: String]
    private let refreshOnUnauthorized: Bool
    private let refreshCoordinator = TokenRefreshCoordinator()

    /// Creates an authenticated HTTP client decorator.
    ///
    /// - Parameters:
    ///   - decoratee: The underlying HTTP client to wrap.
    ///   - baseURL: Base URL to prepend to relative paths (optional).
    ///   - tokenProvider: Provides auth tokens and handles refresh (optional).
    ///   - tokenHeaderKey: Header key for the token (default: `"Authorization"`).
    ///   - tokenPrefix: Prefix before the token value (default: `"Bearer "`).
    ///   - commonHeaders: Headers added to every request (default: empty).
    ///   - commonQueryParameters: Query parameters added to every request (default: empty).
    ///   - refreshOnUnauthorized: Whether to refresh token and retry on 401 (default: `true`).
    public init(
        decoratee: DENNetworkHTTPClient,
        baseURL: URL? = nil,
        tokenProvider: TokenProvider? = nil,
        tokenHeaderKey: String = "Authorization",
        tokenPrefix: String = "Bearer ",
        commonHeaders: [String: String] = [:],
        commonQueryParameters: [String: String] = [:],
        refreshOnUnauthorized: Bool = true
    ) {
        self.decoratee = decoratee
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.tokenHeaderKey = tokenHeaderKey
        self.tokenPrefix = tokenPrefix
        self.commonHeaders = commonHeaders
        self.commonQueryParameters = commonQueryParameters
        self.refreshOnUnauthorized = refreshOnUnauthorized
    }

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let prepared = try await prepareRequest(request)
        let (data, response) = try await decoratee.load(prepared)

        guard response.statusCode == 401,
              refreshOnUnauthorized,
              let tokenProvider else {
            return (data, response)
        }

        // Serialize token refresh — concurrent 401s share one refresh call
        let newToken = try await refreshCoordinator.refresh(using: tokenProvider)
        let refreshed = applyToken(newToken, to: request)
        return try await decoratee.load(refreshed)
    }

    // MARK: - Private

    private func prepareRequest(_ request: URLRequest) async throws -> URLRequest {
        var mutableRequest = applyBaseURL(to: request)

        // Inject auth token
        if let tokenProvider {
            let token = try await tokenProvider.currentToken()
            if !token.isEmpty {
                mutableRequest.setValue(tokenPrefix + token, forHTTPHeaderField: tokenHeaderKey)
            }
        }

        applyCommonHeaders(to: &mutableRequest)
        applyCommonQueryParameters(to: &mutableRequest)

        return mutableRequest
    }

    private func applyToken(_ token: String, to request: URLRequest) -> URLRequest {
        var mutableRequest = applyBaseURL(to: request)

        if !token.isEmpty {
            mutableRequest.setValue(tokenPrefix + token, forHTTPHeaderField: tokenHeaderKey)
        }

        applyCommonHeaders(to: &mutableRequest)
        applyCommonQueryParameters(to: &mutableRequest)

        return mutableRequest
    }

    private func applyBaseURL(to request: URLRequest) -> URLRequest {
        var mutableRequest = request

        if let baseURL, let url = request.url {
            let urlString = url.absoluteString
            let isRelativePath = !urlString.contains("://")
            if isRelativePath {
                let path = urlString.hasPrefix("/") ? String(urlString.dropFirst()) : urlString
                mutableRequest.url = baseURL.appendingPathComponent(path)
            }
        }

        return mutableRequest
    }

    private func applyCommonHeaders(to request: inout URLRequest) {
        for (key, value) in commonHeaders {
            if request.value(forHTTPHeaderField: key) == nil {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }

    private func applyCommonQueryParameters(to request: inout URLRequest) {
        guard !commonQueryParameters.isEmpty,
              let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        var queryItems = components.queryItems ?? []
        for (key, value) in commonQueryParameters {
            if !queryItems.contains(where: { $0.name == key }) {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
        }
        components.queryItems = queryItems
        request.url = components.url
    }
}

// MARK: - Token Refresh Coordinator

/// Serializes concurrent token refresh calls so only one refresh happens at a time.
///
/// When multiple requests receive 401 simultaneously, the first one triggers `refreshToken()`.
/// All subsequent callers await the same in-flight refresh instead of triggering their own.
private actor TokenRefreshCoordinator {
    private var activeRefreshTask: Task<String, Error>?

    func refresh(using provider: TokenProvider) async throws -> String {
        // If a refresh is already in-flight, piggyback on it
        if let activeTask = activeRefreshTask {
            return try await activeTask.value
        }

        // Start a new refresh — all concurrent callers will await this same task
        let task = Task {
            try await provider.refreshToken()
        }
        activeRefreshTask = task

        do {
            let token = try await task.value
            activeRefreshTask = nil
            return token
        } catch {
            activeRefreshTask = nil
            throw error
        }
    }
}
