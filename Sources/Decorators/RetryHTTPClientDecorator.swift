import Foundation

/// Decorator that automatically retries failed requests with exponential backoff.
///
/// Only retries errors where `DENNetworkError.isRetryable` is `true` (timeout, server errors, etc.).
/// Non-retryable errors (unauthorized, not found, cancelled) are thrown immediately.
///
/// Usage:
/// ```swift
/// let client = DENNetworkURLSessionHTTPClient()
/// let retry = RetryHTTPClientDecorator(
///     decoratee: client,
///     maxRetries: 3,
///     baseDelay: 1.0,
///     strategy: .exponential(multiplier: 2.0)
/// )
/// let service = DENNetworkService(client: retry)
/// ```
public final class RetryHTTPClientDecorator: DENNetworkHTTPClient, Sendable {

    /// Backoff strategy between retries.
    public enum Strategy: Sendable {
        /// Fixed delay between retries.
        case constant

        /// Delay doubles (or multiplies) each retry: `baseDelay * multiplier^attempt`.
        case exponential(multiplier: Double = 2.0)

        /// Exponential backoff plus random jitter up to `maxJitter` seconds.
        case exponentialWithJitter(multiplier: Double = 2.0, maxJitter: TimeInterval = 0.5)
    }

    private let decoratee: DENNetworkHTTPClient
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let strategy: Strategy

    /// Creates a retry decorator.
    ///
    /// - Parameters:
    ///   - decoratee: The underlying HTTP client to wrap.
    ///   - maxRetries: Maximum number of retry attempts (default: 3).
    ///   - baseDelay: Initial delay in seconds before the first retry (default: 1.0).
    ///   - maxDelay: Maximum delay cap in seconds (default: 30.0).
    ///   - strategy: Backoff strategy (default: `.exponential()`).
    public init(
        decoratee: DENNetworkHTTPClient,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        strategy: Strategy = .exponential()
    ) {
        self.decoratee = decoratee
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.strategy = strategy
    }

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                try Task.checkCancellation()
                return try await decoratee.load(request)
            } catch let error as DENNetworkError where error.isRetryable && attempt < maxRetries {
                lastError = error
                let delay = calculateDelay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw error
            }
        }

        throw lastError ?? DENNetworkError.unknown(message: "Retry exhausted")
    }

    // MARK: - Private

    /// Visible for testing.
    func calculateDelay(for attempt: Int) -> TimeInterval {
        let raw: TimeInterval
        switch strategy {
        case .constant:
            raw = baseDelay
        case .exponential(let multiplier):
            raw = baseDelay * pow(multiplier, Double(attempt))
        case .exponentialWithJitter(let multiplier, let maxJitter):
            let exponential = baseDelay * pow(multiplier, Double(attempt))
            let jitter = Double.random(in: 0...maxJitter)
            raw = exponential + jitter
        }
        return min(raw, maxDelay)
    }
}
