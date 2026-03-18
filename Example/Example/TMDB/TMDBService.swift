import Foundation
import DENNetworking
import Alamofire

/// Factory that composes the DENNetworking client stack for TMDB.
///
/// Demonstrates how to swap HTTP transport (URLSession ↔ Alamofire) without
/// changing any other code — decorators, service, repository, and views all stay the same.
enum TMDBServiceFactory {

    /// The HTTP transport layer to use.
    enum Transport {
        /// Apple's built-in URLSession (zero dependencies).
        case urlSession

        /// Alamofire-backed client (requires Alamofire SPM dependency).
        /// Add to Xcode: File > Add Package Dependencies > `https://github.com/Alamofire/Alamofire.git`
        case alamofire
    }

    static let apiKey = "YOUR_API_KEY_HERE"

    /// Creates a TMDB service with the specified transport.
    ///
    /// The full client stack:
    /// ```
    /// Transport (URLSession or Alamofire)
    ///     └► TMDBAPIKeyDecorator (injects api_key)
    ///         └► DENNetworkService (status code mapping + JSON decoding)
    /// ```
    ///
    /// - Parameter transport: Which HTTP client to use. Default: `.urlSession`.
    static func make(transport: Transport = .urlSession) -> DENNetworkingServiceProtocol {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let httpClient: DENNetworkHTTPClient = makeHTTPClient(transport: transport)

        let authenticatedClient = TMDBAPIKeyDecorator(
            decoratee: httpClient,
            apiKey: apiKey
        )

        return DENNetworkService(
            client: authenticatedClient,
            decoder: JSONResponseDecoder(decoder: decoder)
        )
    }

    /// Creates a TMDB service with Alamofire + Retry decorator.
    ///
    /// Demonstrates stacking decorators:
    /// ```
    /// Alamofire
    ///     └► TMDBAPIKeyDecorator (injects api_key)
    ///         └► RetryHTTPClientDecorator (retry on 5xx/timeout)
    ///             └► DENNetworkService
    /// ```
    static func makeWithRetry() -> DENNetworkingServiceProtocol {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let httpClient = AlamofireHTTPClient()

        let withApiKey = TMDBAPIKeyDecorator(
            decoratee: httpClient,
            apiKey: apiKey
        )

        let withRetry = RetryHTTPClientDecorator(
            decoratee: withApiKey,
            maxRetries: 2,
            baseDelay: 1.0,
            strategy: .exponentialWithJitter()
        )

        return DENNetworkService(
            client: withRetry,
            decoder: JSONResponseDecoder(decoder: decoder)
        )
    }

    /// Creates a TMDB service using Alamofire with native token refresh.
    ///
    /// Uses Alamofire's `RequestInterceptor` to handle 401 → refresh → retry
    /// at the Alamofire session level. This is Alamofire's native pattern for token management.
    ///
    /// Stack:
    /// ```
    /// Alamofire Session (with AlamofireTokenInterceptor)
    ///     ├── adapt: injects Bearer token on every request
    ///     └── retry: refreshes token on 401, retries once
    ///         └► TMDBAPIKeyDecorator (injects api_key)
    ///             └► DENNetworkService
    /// ```
    ///
    /// - Parameters:
    ///   - tokenStore: Storage for access/refresh tokens. Default: in-memory (use Keychain in production).
    ///   - refreshURL: The token refresh endpoint.
    static func makeWithTokenRefresh(
        tokenStore: AlamofireTokenStore = InMemoryTokenStore(
            accessToken: "your-access-token",
            refreshToken: "your-refresh-token"
        ),
        refreshURL: URL = URL(string: "https://api.example.com/auth/refresh")!
    ) -> DENNetworkingServiceProtocol {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let interceptor = AlamofireTokenInterceptor(
            tokenStore: tokenStore,
            refreshURL: refreshURL
        )

        let session = Session(interceptor: interceptor)
        let httpClient = AlamofireHTTPClient(session: session)

        let withApiKey = TMDBAPIKeyDecorator(
            decoratee: httpClient,
            apiKey: apiKey
        )

        return DENNetworkService(
            client: withApiKey,
            decoder: JSONResponseDecoder(decoder: decoder)
        )
    }

    // MARK: - Private

    private static func makeHTTPClient(transport: Transport) -> DENNetworkHTTPClient {
        switch transport {
        case .urlSession:
            return DENNetworkURLSessionHTTPClient()
        case .alamofire:
            return AlamofireHTTPClient()
        }
    }
}
