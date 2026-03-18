import Foundation
import DENNetworking
import Alamofire

/// DENNetworkHTTPClient implementation backed by Alamofire.
///
/// Drop-in replacement for `DENNetworkURLSessionHTTPClient` — swap it in the factory
/// and everything else (decorators, service, repository, views) works unchanged.
///
/// ## Why use this?
/// - Alamofire's automatic retry via `RequestInterceptor`
/// - Built-in certificate pinning via `ServerTrustManager`
/// - Request/response event monitors
/// - Advanced caching and redirect policies
///
/// ## Usage
/// ```swift
/// // Default session
/// let client = AlamofireHTTPClient()
///
/// // Custom session with pinning
/// let evaluators: [String: ServerTrustEvaluating] = [
///     "api.themoviedb.org": PinnedCertificatesTrustEvaluator()
/// ]
/// let manager = ServerTrustManager(evaluators: evaluators)
/// let session = Session(serverTrustManager: manager)
/// let client = AlamofireHTTPClient(session: session)
/// ```
public final class AlamofireHTTPClient: DENNetworkHTTPClient, @unchecked Sendable {

    private let session: Session

    /// Creates an Alamofire-backed HTTP client.
    ///
    /// - Parameter session: Custom Alamofire `Session`. Defaults to `Session.default`.
    public init(session: Session = .default) {
        self.session = session
    }

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()

        let response = await session.request(request)
            .validate(statusCode: 0..<600) // Don't let Alamofire throw on 4xx/5xx — DENNetworkService handles that
            .serializingData()
            .response

        guard let httpResponse = response.response else {
            throw mapError(response.error)
        }

        switch response.result {
        case .success(let data):
            return (data, httpResponse)
        case .failure(let afError):
            throw mapError(afError)
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: AFError?) -> DENNetworkError {
        guard let error else {
            return .invalidResponseWith(data: Data())
        }

        // Check for underlying URLError
        if let urlError = error.underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .notConnected
            case .cancelled:
                return .cancelled
            case .timedOut:
                return .timeout
            default:
                return .generic(urlError.localizedDescription)
            }
        }

        // Map Alamofire-specific errors
        switch error {
        case .sessionTaskFailed(let underlying):
            if let urlError = underlying as? URLError {
                return mapURLError(urlError)
            }
            return .generic(underlying.localizedDescription)

        case .requestRetryFailed(let retryError, _):
            return .generic(retryError.localizedDescription)

        case .serverTrustEvaluationFailed:
            return .generic("Server certificate validation failed.")

        case .sessionInvalidated:
            return .cancelled

        case .explicitlyCancelled:
            return .cancelled

        default:
            return .generic(error.localizedDescription)
        }
    }

    private func mapURLError(_ error: URLError) -> DENNetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .notConnected
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timeout
        default:
            return .generic(error.localizedDescription)
        }
    }
}
