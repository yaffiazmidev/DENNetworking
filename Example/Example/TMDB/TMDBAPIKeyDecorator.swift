import Foundation
import DENNetworking

/// Decorator that injects the TMDB API key as a query parameter on every request.
///
/// Demonstrates the Decorator pattern from DENNetworking — wraps any `DENNetworkHTTPClient`
/// to add cross-cutting concerns without modifying the original client.
final class TMDBAPIKeyDecorator: DENNetworkHTTPClient, @unchecked Sendable {

    private let decoratee: DENNetworkHTTPClient
    private let apiKey: String

    init(decoratee: DENNetworkHTTPClient, apiKey: String) {
        self.decoratee = decoratee
        self.apiKey = apiKey
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request

        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return try await decoratee.load(request)
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "api_key", value: apiKey))
        components.queryItems = queryItems

        mutableRequest.url = components.url

        return try await decoratee.load(mutableRequest)
    }
}
