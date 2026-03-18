import XCTest
@testable import DENNetworking

final class DENNetworkErrorTests: XCTestCase {

    // MARK: - isRetryable

    func test_retryableErrors() {
        let retryable: [DENNetworkError] = [
            .timeout,
            .serverError(statusCode: 500),
            .httpError(statusCode: 418, data: nil),
            .generic("something"),
            .invalidResponseWith(data: Data()),
            .unknown(message: "unknown"),
        ]

        for error in retryable {
            XCTAssertTrue(error.isRetryable, "\(error) should be retryable")
        }
    }

    func test_nonRetryableErrors() {
        let nonRetryable: [DENNetworkError] = [
            .cancelled,
            .notConnected,
            .decodingError(message: "bad"),
            .unauthorized,
            .forbidden,
            .notFound,
            .badRequest(message: "bad"),
            .urlGeneration,
            .tooManyRequests,
        ]

        for error in nonRetryable {
            XCTAssertFalse(error.isRetryable, "\(error) should NOT be retryable")
        }
    }

    // MARK: - hasStatusCode

    func test_hasStatusCode_httpError() {
        let error = DENNetworkError.httpError(statusCode: 418, data: nil)
        XCTAssertTrue(error.hasStatusCode(418))
        XCTAssertFalse(error.hasStatusCode(500))
    }

    func test_hasStatusCode_serverError() {
        let error = DENNetworkError.serverError(statusCode: 503)
        XCTAssertTrue(error.hasStatusCode(503))
        XCTAssertFalse(error.hasStatusCode(500))
    }

    func test_hasStatusCode_namedErrors() {
        XCTAssertTrue(DENNetworkError.unauthorized.hasStatusCode(401))
        XCTAssertTrue(DENNetworkError.forbidden.hasStatusCode(403))
        XCTAssertTrue(DENNetworkError.notFound.hasStatusCode(404))
        XCTAssertTrue(DENNetworkError.badRequest(message: "").hasStatusCode(400))
        XCTAssertTrue(DENNetworkError.tooManyRequests.hasStatusCode(429))
        XCTAssertTrue(DENNetworkError.timeout.hasStatusCode(408))
    }

    func test_hasStatusCode_nonHTTPError_returnsFalse() {
        XCTAssertFalse(DENNetworkError.notConnected.hasStatusCode(0))
        XCTAssertFalse(DENNetworkError.cancelled.hasStatusCode(0))
    }

    // MARK: - isNotFoundError

    func test_isNotFoundError() {
        XCTAssertTrue(DENNetworkError.notFound.isNotFoundError)
        XCTAssertTrue(DENNetworkError.httpError(statusCode: 404, data: nil).isNotFoundError)
        XCTAssertFalse(DENNetworkError.unauthorized.isNotFoundError)
    }

    // MARK: - LocalizedError

    func test_allCases_haveErrorDescription() {
        let allCases: [DENNetworkError] = [
            .httpError(statusCode: 418, data: nil),
            .notConnected,
            .cancelled,
            .generic("test"),
            .urlGeneration,
            .invalidResponseWith(data: Data()),
            .decodingError(message: "test"),
            .unknown(message: "test"),
            .unauthorized,
            .forbidden,
            .notFound,
            .serverError(statusCode: 500),
            .badRequest(message: "test"),
            .timeout,
            .tooManyRequests,
        ]

        for error in allCases {
            XCTAssertNotNil(error.errorDescription, "\(error) should have errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) errorDescription should not be empty")
        }
    }

    // MARK: - statusCode

    func test_statusCode_returnsCorrectCode() {
        XCTAssertEqual(DENNetworkError.unauthorized.statusCode, 401)
        XCTAssertEqual(DENNetworkError.forbidden.statusCode, 403)
        XCTAssertEqual(DENNetworkError.notFound.statusCode, 404)
        XCTAssertEqual(DENNetworkError.badRequest(message: "").statusCode, 400)
        XCTAssertEqual(DENNetworkError.timeout.statusCode, 408)
        XCTAssertEqual(DENNetworkError.tooManyRequests.statusCode, 429)
        XCTAssertEqual(DENNetworkError.serverError(statusCode: 503).statusCode, 503)
        XCTAssertEqual(DENNetworkError.httpError(statusCode: 418, data: nil).statusCode, 418)
    }

    func test_statusCode_returnsNilForNonHTTPErrors() {
        XCTAssertNil(DENNetworkError.notConnected.statusCode)
        XCTAssertNil(DENNetworkError.cancelled.statusCode)
        XCTAssertNil(DENNetworkError.generic("test").statusCode)
        XCTAssertNil(DENNetworkError.urlGeneration.statusCode)
        XCTAssertNil(DENNetworkError.decodingError(message: "test").statusCode)
    }

    // MARK: - isClientError / isServerError

    func test_isClientError() {
        XCTAssertTrue(DENNetworkError.unauthorized.isClientError)
        XCTAssertTrue(DENNetworkError.notFound.isClientError)
        XCTAssertTrue(DENNetworkError.httpError(statusCode: 422, data: nil).isClientError)
        XCTAssertFalse(DENNetworkError.serverError(statusCode: 500).isClientError)
        XCTAssertFalse(DENNetworkError.notConnected.isClientError)
    }

    func test_isServerError() {
        XCTAssertTrue(DENNetworkError.serverError(statusCode: 500).isServerError)
        XCTAssertTrue(DENNetworkError.serverError(statusCode: 503).isServerError)
        XCTAssertFalse(DENNetworkError.unauthorized.isServerError)
        XCTAssertFalse(DENNetworkError.notConnected.isServerError)
    }

    // MARK: - Equatable

    func test_equatable() {
        XCTAssertEqual(DENNetworkError.notConnected, DENNetworkError.notConnected)
        XCTAssertEqual(DENNetworkError.httpError(statusCode: 418, data: nil), DENNetworkError.httpError(statusCode: 418, data: nil))
        XCTAssertNotEqual(DENNetworkError.notConnected, DENNetworkError.cancelled)
    }
}
