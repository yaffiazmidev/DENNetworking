import XCTest
@testable import DENNetworking

final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {

    // MARK: - Base URL

    func test_load_prependsBaseURLToRelativePath() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            baseURL: URL(string: "https://api.example.com")!
        )

        let request = URLRequest(url: URL(string: "v1/users")!)
        _ = try await sut.load(request)

        let loadedURL = client.lastRequest?.url?.absoluteString
        XCTAssertTrue(loadedURL?.contains("api.example.com") == true)
        XCTAssertTrue(loadedURL?.contains("v1/users") == true)
    }

    func test_load_doesNotPrependBaseURLToAbsoluteURL() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            baseURL: URL(string: "https://api.example.com")!
        )

        let request = URLRequest(url: URL(string: "https://other.com/v1/users")!)
        _ = try await sut.load(request)

        XCTAssertEqual(client.lastRequest?.url?.host, "other.com")
    }

    // MARK: - Token Injection

    func test_load_injectsAuthorizationHeader() async throws {
        let tokenProvider = StubTokenProvider(token: "test-token-123")
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        _ = try await sut.load(request)

        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token-123")
    }

    func test_load_usesCustomTokenHeaderAndPrefix() async throws {
        let tokenProvider = StubTokenProvider(token: "my-api-key")
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider,
            tokenHeaderKey: "X-API-Key",
            tokenPrefix: ""
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        _ = try await sut.load(request)

        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "X-API-Key"), "my-api-key")
        XCTAssertNil(client.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_load_doesNotInjectEmptyToken() async throws {
        let tokenProvider = StubTokenProvider(token: "")
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        _ = try await sut.load(request)

        XCTAssertNil(client.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Token Refresh on 401

    func test_load_refreshesTokenAndRetriesOn401() async throws {
        let tokenProvider = StubTokenProvider(token: "old-token", refreshedToken: "new-token")
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 200)
        ])
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        let (_, response) = try await sut.load(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(client.loadCallCount, 2)
        XCTAssertTrue(tokenProvider.didRefresh)
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
    }

    func test_load_doesNotRefreshWhenDisabled() async throws {
        let tokenProvider = StubTokenProvider(token: "old-token", refreshedToken: "new-token")
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401)
        ])
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider,
            refreshOnUnauthorized: false
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        let (_, response) = try await sut.load(request)

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(client.loadCallCount, 1)
        XCTAssertFalse(tokenProvider.didRefresh)
    }

    func test_load_doesNotRefreshWithoutTokenProvider() async throws {
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401)
        ])
        let sut = AuthenticatedHTTPClientDecorator(decoratee: client)

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        let (_, response) = try await sut.load(request)

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(client.loadCallCount, 1)
    }

    // MARK: - Common Headers

    func test_load_injectsCommonHeaders() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            commonHeaders: ["Accept": "application/json", "X-Platform": "iOS"]
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        _ = try await sut.load(request)

        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "X-Platform"), "iOS")
    }

    func test_load_doesNotOverwriteExistingHeaders() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            commonHeaders: ["Accept": "application/json"]
        )

        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        _ = try await sut.load(request)

        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Accept"), "text/html")
    }

    // MARK: - Common Query Parameters

    func test_load_injectsCommonQueryParameters() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            commonQueryParameters: ["api_key": "abc123"]
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        _ = try await sut.load(request)

        let url = client.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("api_key=abc123"))
    }

    func test_load_doesNotOverwriteExistingQueryParameters() async throws {
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            commonQueryParameters: ["page": "1"]
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users?page=5")!)
        _ = try await sut.load(request)

        let url = client.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("page=5"))
        XCTAssertFalse(url.contains("page=1"))
    }

    // MARK: - Combined

    func test_load_combinesBaseURLTokenAndHeaders() async throws {
        let tokenProvider = StubTokenProvider(token: "jwt-token")
        let client = RequestCapturingStub()
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            baseURL: URL(string: "https://api.example.com")!,
            tokenProvider: tokenProvider,
            commonHeaders: ["Accept": "application/json"],
            commonQueryParameters: ["version": "2"]
        )

        let request = URLRequest(url: URL(string: "v1/users")!)
        _ = try await sut.load(request)

        let loadedRequest = client.lastRequest!
        let url = loadedRequest.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("api.example.com"))
        XCTAssertTrue(url.contains("v1/users"))
        XCTAssertTrue(url.contains("version=2"))
        XCTAssertEqual(loadedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer jwt-token")
        XCTAssertEqual(loadedRequest.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    // MARK: - Token Refresh Serialization (Race Condition Prevention)

    func test_load_concurrent401s_onlyRefreshesOnce() async throws {
        let tokenProvider = CountingTokenProvider(token: "old", refreshedToken: "new")
        // Each concurrent request: initial call (401) + retry after refresh (200)
        // 3 requests × 2 calls each = 6 responses needed
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 200),
            makeResponse(statusCode: 200),
            makeResponse(statusCode: 200)
        ])
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // Fire 3 concurrent requests that all get 401
        async let r1: (Data, HTTPURLResponse) = sut.load(request)
        async let r2: (Data, HTTPURLResponse) = sut.load(request)
        async let r3: (Data, HTTPURLResponse) = sut.load(request)

        let results = try await [r1, r2, r3]

        // All should succeed after refresh
        for (_, response) in results {
            XCTAssertEqual(response.statusCode, 200)
        }

        // Token refresh should only be called once (serialized by actor)
        XCTAssertEqual(tokenProvider.refreshCallCount, 1)
    }

    func test_load_refreshError_propagatesToAllWaiters() async {
        let tokenProvider = FailingTokenProvider(
            token: "old",
            refreshError: DENNetworkError.unauthorized
        )
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 401)
        ])
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // Both should fail with the refresh error
        async let r1: Void = {
            do {
                _ = try await sut.load(request)
                XCTFail("Expected error")
            } catch {
                XCTAssertTrue(error is DENNetworkError)
            }
        }()

        async let r2: Void = {
            do {
                _ = try await sut.load(request)
                XCTFail("Expected error")
            } catch {
                XCTAssertTrue(error is DENNetworkError)
            }
        }()

        _ = await (r1, r2)
    }

    func test_load_afterFailedRefresh_canRefreshAgain() async throws {
        let tokenProvider = RecoverableTokenProvider(
            token: "old",
            refreshResults: [.failure(DENNetworkError.generic("temp error")), .success("new-token")]
        )
        let client = RequestCapturingStub(responses: [
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 401),
            makeResponse(statusCode: 200)
        ])
        let sut = AuthenticatedHTTPClientDecorator(
            decoratee: client,
            tokenProvider: tokenProvider
        )

        let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

        // First attempt: refresh fails
        do {
            _ = try await sut.load(request)
            XCTFail("Expected error")
        } catch {
            // expected — refresh failed
        }

        // Second attempt: refresh succeeds (actor cleared the failed task)
        let (_, response) = try await sut.load(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - Helpers

    private func makeResponse(statusCode: Int = 200) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

// MARK: - Test Doubles

private final class StubTokenProvider: TokenProvider, @unchecked Sendable {
    private let token: String
    private let refreshedToken: String
    private(set) var didRefresh = false

    init(token: String, refreshedToken: String = "") {
        self.token = token
        self.refreshedToken = refreshedToken
    }

    func currentToken() async throws -> String {
        token
    }

    func refreshToken() async throws -> String {
        didRefresh = true
        return refreshedToken
    }
}

private final class CountingTokenProvider: TokenProvider, @unchecked Sendable {
    private let token: String
    private let refreshedToken: String
    private let lock = NSLock()
    private var _refreshCallCount = 0
    var refreshCallCount: Int { lock.withLock { _refreshCallCount } }

    init(token: String, refreshedToken: String) {
        self.token = token
        self.refreshedToken = refreshedToken
    }

    func currentToken() async throws -> String {
        token
    }

    func refreshToken() async throws -> String {
        // Small delay to simulate real network call and increase race window
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        lock.withLock { _refreshCallCount += 1 }
        return refreshedToken
    }
}

private final class FailingTokenProvider: TokenProvider, @unchecked Sendable {
    private let token: String
    private let refreshError: Error

    init(token: String, refreshError: Error) {
        self.token = token
        self.refreshError = refreshError
    }

    func currentToken() async throws -> String { token }
    func refreshToken() async throws -> String { throw refreshError }
}

private final class RecoverableTokenProvider: TokenProvider, @unchecked Sendable {
    private let token: String
    private var refreshResults: [Result<String, Error>]
    private var callIndex = 0

    init(token: String, refreshResults: [Result<String, Error>]) {
        self.token = token
        self.refreshResults = refreshResults
    }

    func currentToken() async throws -> String { token }

    func refreshToken() async throws -> String {
        let index = min(callIndex, refreshResults.count - 1)
        callIndex += 1
        return try refreshResults[index].get()
    }
}

private final class RequestCapturingStub: DENNetworkHTTPClient, @unchecked Sendable {
    private var responses: [(Data, HTTPURLResponse)]
    private(set) var lastRequest: URLRequest?
    private(set) var loadCallCount = 0
    private let lock = NSLock()

    init(responses: [(Data, HTTPURLResponse)]? = nil) {
        let defaultResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        self.responses = responses ?? [(Data(), defaultResponse)]
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        lastRequest = request
        let index = min(loadCallCount, responses.count - 1)
        loadCallCount += 1
        lock.unlock()
        return responses[index]
    }
}
