import Foundation

/// Unified error type for all networking failures.
///
/// Covers transport errors (no connection, timeout), HTTP status errors (401, 404, 500),
/// and client-side errors (decoding, URL generation). Use `isRetryable` to determine
/// if a request should be retried, and `hasStatusCode(_:)` to match specific HTTP codes.
public enum DENNetworkError: Error, Equatable, Sendable {
    /// Unhandled HTTP status code with optional response body for inspection.
    case error(statusCode: Int, data: Data?)
    case notConnected
    case cancelled
    /// Wraps non-network errors. Stores `localizedDescription` (not the original `Error`)
    /// to satisfy `Equatable` and `Sendable`.
    case generic(String)
    case urlGeneration
    /// HTTP response was not a valid `HTTPURLResponse`. Carries raw data for debugging.
    case invalidResponseWith(data: Data)
    case decodingError(message: String)
    case unknown(message: String)
    /// HTTP 401
    case unauthorized
    /// HTTP 403
    case forbidden
    /// HTTP 404
    case notFound
    /// HTTP 500-599
    case serverError(statusCode: Int)
    /// HTTP 400 — carries the response body as message.
    case badRequest(message: String)
    /// `URLError.timedOut` or HTTP 408
    case timeout
    /// HTTP 429
    case tooManyRequests
}

extension DENNetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .error(statusCode, _):
            return "Server error (\(statusCode))."
        case .notConnected:
            return "No internet connection."
        case .cancelled:
            return "Request was cancelled."
        case .generic:
            return "Something went wrong. Please try again."
        case .urlGeneration:
            return "Failed to build URL."
        case .invalidResponseWith:
            return "Invalid server response."
        case let .decodingError(message):
            return message
        case let .unknown(message):
            return "Unknown error: \(message)"
        case .unauthorized:
            return "Unauthorized access. Please check your credentials."
        case .forbidden:
            return "Access forbidden. You don't have permission."
        case .notFound:
            return "The requested resource could not be found."
        case .serverError(let statusCode):
            return "Server error occurred. Status code: \(statusCode)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .tooManyRequests:
            return "Too many requests. Please try again later."
        }
    }
}

public extension DENNetworkError {
    var isNotFoundError: Bool {
        switch self {
        case .notFound:
            return true
        default:
            return hasStatusCode(404)
        }
    }

    /// Whether this error is transient and the request can be retried.
    ///
    /// Retryable: `timeout`, `serverError`, `error`, `generic`, `invalidResponseWith`, `unknown`.
    /// Not retryable: `cancelled`, `notConnected`, `decodingError`, `unauthorized`, `forbidden`,
    /// `notFound`, `badRequest`, `urlGeneration`, `tooManyRequests`.
    var isRetryable: Bool {
        switch self {
        case .timeout, .serverError, .error, .generic, .invalidResponseWith, .unknown:
            return true
        case .cancelled, .notConnected, .decodingError, .unauthorized, .forbidden,
             .notFound, .badRequest, .urlGeneration, .tooManyRequests:
            return false
        }
    }

    /// Checks if this error corresponds to the given HTTP status code.
    func hasStatusCode(_ codeError: Int) -> Bool {
        switch self {
        case let .error(code, _):
            return code == codeError
        case .serverError(let code):
            return code == codeError
        case .unauthorized:
            return codeError == 401
        case .forbidden:
            return codeError == 403
        case .notFound:
            return codeError == 404
        case .badRequest:
            return codeError == 400
        case .tooManyRequests:
            return codeError == 429
        default:
            return false
        }
    }
}
