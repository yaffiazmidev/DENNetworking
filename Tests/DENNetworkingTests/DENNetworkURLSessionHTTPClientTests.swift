import XCTest
@testable import DENNetworking

/// Integration tests for `DENNetworkURLSessionHTTPClient` using a real `URLSession`
/// with `URLProtocolStub` to intercept and control network responses without hitting the network.
final class DENNetworkURLSessionHTTPClientTests: XCTestCase {

    private var sut: DENNetworkURLSessionHTTPClient!
    private let testURL = URL(string: "https://integration-test.example.com/api")!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        sut = makeSUT()
    }

    override func tearDown() {
        sut = nil
        URLProtocolStub.clean()
        super.tearDown()
    }

    // MARK: - Success Cases

    func test_load_deliversDataAndHTTPResponseOn200() async throws {
        // Arrange
        let expectedData = Data("""
            {"id": 1, "name": "DENNetworking"}
            """.utf8)
        let expectedResponse = makeHTTPResponse(statusCode: 200)
        URLProtocolStub.stub(data: expectedData, response: expectedResponse, error: nil)

        // Act
        let (data, response) = try await sut.load(makeRequest())

        // Assert
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_load_deliversEmptyDataOn200() async throws {
        // Arrange
        let expectedResponse = makeHTTPResponse(statusCode: 200)
        URLProtocolStub.stub(data: Data(), response: expectedResponse, error: nil)

        // Act
        let (data, response) = try await sut.load(makeRequest())

        // Assert
        XCTAssertEqual(data, Data())
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - Non-200 HTTP Status Codes

    func test_load_deliversDataAndHTTPResponseOn404() async throws {
        // Arrange — the client does not validate status codes; it returns any valid HTTPURLResponse as-is.
        let expectedData = Data("""
            {"error": "not found"}
            """.utf8)
        let expectedResponse = makeHTTPResponse(statusCode: 404)
        URLProtocolStub.stub(data: expectedData, response: expectedResponse, error: nil)

        // Act
        let (data, response) = try await sut.load(makeRequest())

        // Assert — raw (Data, HTTPURLResponse) is returned regardless of status code.
        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, 404)
    }

    // MARK: - Transport Error Mapping

    func test_load_throwsNotConnectedOnNoInternetError() async {
        // Arrange
        let noInternetError = URLError(.notConnectedToInternet)
        URLProtocolStub.stub(data: nil, response: nil, error: noInternetError)

        // Act & Assert
        await assertThrows(DENNetworkError.notConnected) {
            try await self.sut.load(self.makeRequest())
        }
    }

    func test_load_throwsCancelledOnURLCancelledError() async {
        // Arrange
        let cancelledError = URLError(.cancelled)
        URLProtocolStub.stub(data: nil, response: nil, error: cancelledError)

        // Act & Assert
        await assertThrows(DENNetworkError.cancelled) {
            try await self.sut.load(self.makeRequest())
        }
    }

    func test_load_throwsTimeoutOnTimedOutError() async {
        // Arrange
        let timeoutError = URLError(.timedOut)
        URLProtocolStub.stub(data: nil, response: nil, error: timeoutError)

        // Act & Assert
        await assertThrows(DENNetworkError.timeout) {
            try await self.sut.load(self.makeRequest())
        }
    }

    func test_load_throwsNotConnectedOnNetworkConnectionLostError() async {
        // Arrange
        let connectionLostError = URLError(.networkConnectionLost)
        URLProtocolStub.stub(data: nil, response: nil, error: connectionLostError)

        // Act & Assert
        await assertThrows(DENNetworkError.notConnected) {
            try await self.sut.load(self.makeRequest())
        }
    }

    func test_load_throwsGenericErrorOnUnknownURLError() async {
        // Arrange
        let unknownError = URLError(.unknown)
        URLProtocolStub.stub(data: nil, response: nil, error: unknownError)

        // Act & Assert
        do {
            try await sut.load(makeRequest())
            XCTFail("Expected DENNetworkError.generic to be thrown")
        } catch let error as DENNetworkError {
            if case .generic = error {
                // Expected
            } else {
                XCTFail("Expected .generic, got \(error)")
            }
        } catch {
            XCTFail("Unexpected non-DENNetworkError thrown: \(error)")
        }
    }

    // MARK: - Invalid (Non-HTTP) Response

    func test_load_throwsInvalidResponseWhenResponseIsNotHTTPURLResponse() async throws {
        // Arrange — URLResponse is a plain response, not an HTTPURLResponse.
        let nonHTTPResponse = URLResponse(
            url: testURL,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        let data = Data("some data".utf8)
        URLProtocolStub.stub(data: data, response: nonHTTPResponse, error: nil)

        // Act & Assert
        do {
            try await sut.load(makeRequest())
            XCTFail("Expected DENNetworkError.invalidResponseWith to be thrown")
        } catch let error as DENNetworkError {
            if case let .invalidResponseWith(receivedData) = error {
                XCTAssertEqual(receivedData, data)
            } else {
                XCTFail("Expected .invalidResponseWith, got \(error)")
            }
        } catch {
            XCTFail("Unexpected non-DENNetworkError thrown: \(error)")
        }
    }

    // MARK: - Task Cancellation

    func test_load_throwsCancelledWhenTaskIsCancelledBeforeExecution() async {
        // Arrange — cancel the task before load is called.
        let task = Task<Void, Error> {
            try Task.checkCancellation()
            try await self.sut.load(self.makeRequest())
        }
        task.cancel()

        do {
            try await task.value
            XCTFail("Expected cancellation error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .cancelled)
        } catch is CancellationError {
            // Also acceptable — Swift may surface CancellationError directly before the client maps it.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Helpers

private extension DENNetworkURLSessionHTTPClientTests {

    func makeSUT() -> DENNetworkURLSessionHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        return DENNetworkURLSessionHTTPClient(session: session)
    }

    func makeRequest() -> URLRequest {
        URLRequest(url: testURL)
    }

    func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: testURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func assertThrows(
        _ expected: DENNetworkError,
        _ operation: () async throws -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected error \(expected) to be thrown", file: file, line: line)
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected non-DENNetworkError thrown: \(error)", file: file, line: line)
        }
    }
}
