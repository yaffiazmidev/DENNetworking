import XCTest
@testable import DENNetworking

final class RetryHTTPClientDecoratorTests: XCTestCase {

    // MARK: - Success Without Retry

    func test_load_succeedsOnFirstAttempt_doesNotRetry() async throws {
        let client = CountingHTTPClientStub(results: [.success(makeResponse())])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        _ = try await sut.load(makeRequest())

        XCTAssertEqual(client.loadCallCount, 1)
    }

    // MARK: - Retry on Retryable Errors

    func test_load_retriesOnTimeout_thenSucceeds() async throws {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.timeout),
            .success(makeResponse())
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        let (_, response) = try await sut.load(makeRequest())

        XCTAssertEqual(client.loadCallCount, 2)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_load_retriesOnServerError_thenSucceeds() async throws {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.serverError(statusCode: 500)),
            .failure(DENNetworkError.serverError(statusCode: 502)),
            .success(makeResponse())
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        let (_, response) = try await sut.load(makeRequest())

        XCTAssertEqual(client.loadCallCount, 3)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - Exhausted Retries

    func test_load_throwsAfterExhaustingRetries() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.timeout),
            .failure(DENNetworkError.timeout),
            .failure(DENNetworkError.timeout),
            .failure(DENNetworkError.timeout)
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .timeout)
            XCTAssertEqual(client.loadCallCount, 4) // 1 initial + 3 retries
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Non-Retryable Errors

    func test_load_doesNotRetryUnauthorized() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.unauthorized)
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(client.loadCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_load_doesNotRetryNotFound() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.notFound)
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notFound)
            XCTAssertEqual(client.loadCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_load_doesNotRetryCancelled() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.cancelled)
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .cancelled)
            XCTAssertEqual(client.loadCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_load_doesNotRetryDecodingError() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.decodingError(message: "bad json"))
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 3, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .decodingError(message: "bad json"))
            XCTAssertEqual(client.loadCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Zero Retries

    func test_load_zeroRetries_throwsImmediately() async {
        let client = CountingHTTPClientStub(results: [
            .failure(DENNetworkError.timeout)
        ])
        let sut = RetryHTTPClientDecorator(decoratee: client, maxRetries: 0, baseDelay: 0.01)

        do {
            _ = try await sut.load(makeRequest())
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .timeout)
            XCTAssertEqual(client.loadCallCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Delay Calculation

    func test_calculateDelay_constant() {
        let sut = RetryHTTPClientDecorator(
            decoratee: CountingHTTPClientStub(results: []),
            baseDelay: 2.0,
            strategy: .constant
        )

        XCTAssertEqual(sut.calculateDelay(for: 0), 2.0)
        XCTAssertEqual(sut.calculateDelay(for: 1), 2.0)
        XCTAssertEqual(sut.calculateDelay(for: 5), 2.0)
    }

    func test_calculateDelay_exponential() {
        let sut = RetryHTTPClientDecorator(
            decoratee: CountingHTTPClientStub(results: []),
            baseDelay: 1.0,
            maxDelay: 30.0,
            strategy: .exponential(multiplier: 2.0)
        )

        XCTAssertEqual(sut.calculateDelay(for: 0), 1.0)  // 1 * 2^0
        XCTAssertEqual(sut.calculateDelay(for: 1), 2.0)  // 1 * 2^1
        XCTAssertEqual(sut.calculateDelay(for: 2), 4.0)  // 1 * 2^2
        XCTAssertEqual(sut.calculateDelay(for: 3), 8.0)  // 1 * 2^3
    }

    func test_calculateDelay_capsAtMaxDelay() {
        let sut = RetryHTTPClientDecorator(
            decoratee: CountingHTTPClientStub(results: []),
            baseDelay: 1.0,
            maxDelay: 5.0,
            strategy: .exponential(multiplier: 2.0)
        )

        XCTAssertEqual(sut.calculateDelay(for: 0), 1.0)
        XCTAssertEqual(sut.calculateDelay(for: 1), 2.0)
        XCTAssertEqual(sut.calculateDelay(for: 2), 4.0)
        XCTAssertEqual(sut.calculateDelay(for: 3), 5.0) // capped
        XCTAssertEqual(sut.calculateDelay(for: 10), 5.0) // capped
    }

    func test_calculateDelay_exponentialWithJitter_isWithinRange() {
        let sut = RetryHTTPClientDecorator(
            decoratee: CountingHTTPClientStub(results: []),
            baseDelay: 1.0,
            maxDelay: 30.0,
            strategy: .exponentialWithJitter(multiplier: 2.0, maxJitter: 0.5)
        )

        for _ in 0..<20 {
            let delay = sut.calculateDelay(for: 1)
            // 1.0 * 2^1 = 2.0, jitter 0..0.5 → range [2.0, 2.5]
            XCTAssertGreaterThanOrEqual(delay, 2.0)
            XCTAssertLessThanOrEqual(delay, 2.5)
        }
    }

    // MARK: - Helpers

    private func makeRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://test.com/api")!)
    }

    private func makeResponse(statusCode: Int = 200) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com/api")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

// MARK: - Test Helper

private final class CountingHTTPClientStub: DENNetworkHTTPClient, @unchecked Sendable {
    private var results: [Result<(Data, HTTPURLResponse), Error>]
    private(set) var loadCallCount = 0

    init(results: [Result<(Data, HTTPURLResponse), Error>]) {
        self.results = results
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = min(loadCallCount, results.count - 1)
        loadCallCount += 1
        return try results[index].get()
    }
}
