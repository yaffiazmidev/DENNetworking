import XCTest
@testable import DENNetworking

private struct TestModel: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

final class DENNetworkServiceTests: XCTestCase {

    private let dummyRequest = try! URLRequest.url("https://test.com/api").method(.GET).build()

    // MARK: - Success

    func test_execute_decodesSuccessResponse() async throws {
        let model = TestModel(id: 1, name: "Den")
        let data = try JSONEncoder().encode(model)
        let client = HTTPClientStub.success(data: data, statusCode: 200)
        let sut = DENNetworkService(client: client)

        let result: TestModel = try await sut.execute(dummyRequest)

        XCTAssertEqual(result, model)
    }

    func test_execute_void_succeedsOn204() async throws {
        let client = HTTPClientStub.success(data: Data(), statusCode: 204)
        let sut = DENNetworkService(client: client)

        try await sut.execute(dummyRequest)
    }

    func test_execute_void_throwsUnauthorizedOn401() async {
        let client = HTTPClientStub.success(statusCode: 401)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.unauthorized) {
            try await sut.execute(dummyRequest)
        }
    }

    func test_execute_void_throwsServerErrorOn500() async {
        let client = HTTPClientStub.success(statusCode: 500)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.serverError(statusCode: 500)) {
            try await sut.execute(dummyRequest)
        }
    }

    // MARK: - Status Code Mapping

    func test_execute_throws_badRequest_on400() async {
        let client = HTTPClientStub.success(data: Data("bad input".utf8), statusCode: 400)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.badRequest(message: "bad input")) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_unauthorized_on401() async {
        let client = HTTPClientStub.success(statusCode: 401)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.unauthorized) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_forbidden_on403() async {
        let client = HTTPClientStub.success(statusCode: 403)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.forbidden) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_notFound_on404() async {
        let client = HTTPClientStub.success(statusCode: 404)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.notFound) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_timeout_on408() async {
        let client = HTTPClientStub.success(statusCode: 408)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.timeout) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_tooManyRequests_on429() async {
        let client = HTTPClientStub.success(statusCode: 429)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.tooManyRequests) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_httpError_onOther4xx() async {
        let client = HTTPClientStub.success(data: Data("conflict".utf8), statusCode: 409)
        let sut = DENNetworkService(client: client)

        do {
            let _: TestModel = try await sut.execute(dummyRequest)
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertTrue(error.hasStatusCode(409))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_throws_serverError_on500() async {
        let client = HTTPClientStub.success(statusCode: 500)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.serverError(statusCode: 500)) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    func test_execute_throws_serverError_on503() async {
        let client = HTTPClientStub.success(statusCode: 503)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.serverError(statusCode: 503)) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    // MARK: - Decoding Error

    func test_execute_throws_decodingError_onInvalidJSON() async {
        let client = HTTPClientStub.success(data: Data("not json".utf8), statusCode: 200)
        let sut = DENNetworkService(client: client)

        do {
            let _: TestModel = try await sut.execute(dummyRequest)
            XCTFail("Expected decoding error")
        } catch let error as DENNetworkError {
            if case .decodingError = error {
                // expected
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Transport Error Propagation

    func test_execute_propagatesClientError() async {
        let client = HTTPClientStub.failure(DENNetworkError.notConnected)
        let sut = DENNetworkService(client: client)

        await assertThrows(DENNetworkError.notConnected) {
            let _: TestModel = try await sut.execute(dummyRequest)
        }
    }

    // MARK: - Custom Decoder

    func test_execute_usesCustomDecoder() async throws {
        let model = TestModel(id: 1, name: "Den")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(model)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let client = HTTPClientStub.success(data: data, statusCode: 200)
        let sut = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))

        let result: TestModel = try await sut.execute(dummyRequest)
        XCTAssertEqual(result, model)
    }

    // MARK: - Builder Convenience

    func test_execute_builder_decodesSuccessResponse() async throws {
        let model = TestModel(id: 1, name: "Den")
        let data = try JSONEncoder().encode(model)
        let client = HTTPClientStub.success(data: data, statusCode: 200)
        let sut = DENNetworkService(client: client)

        let result: TestModel = try await sut.execute(
            .url("https://test.com/api").method(.GET)
        )

        XCTAssertEqual(result, model)
    }

    func test_execute_builder_void_succeedsOn204() async throws {
        let client = HTTPClientStub.success(data: Data(), statusCode: 204)
        let sut = DENNetworkService(client: client)

        try await sut.execute(
            .url("https://test.com/api").method(.DELETE)
        )
    }

    // MARK: - RawDataResponseDecoder

    func test_rawDataDecoder_returnsData() async throws {
        let expectedData = Data("raw content".utf8)
        let client = HTTPClientStub.success(data: expectedData, statusCode: 200)
        let sut = DENNetworkService(client: client, decoder: RawDataResponseDecoder())

        let result: Data = try await sut.execute(dummyRequest)
        XCTAssertEqual(result, expectedData)
    }

    // MARK: - Helper

    private func assertThrows(
        _ expected: DENNetworkError,
        _ operation: () async throws -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected error \(expected)", file: file, line: line)
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
