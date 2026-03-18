import XCTest
@testable import DENNetworking

final class URLRequestBuilderTests: XCTestCase {

    // MARK: - Basic URL Building

    func test_url_buildsCorrectRequest() throws {
        let request = try URLRequest
            .url("https://api.example.com/v1/users")
            .method(.GET)
            .build()

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_url_preservesPort() throws {
        let request = try URLRequest
            .url("https://api.example.com:8080/v1/users")
            .build()

        XCTAssertEqual(request.url?.port, 8080)
    }

    func test_url_preservesQueryFromURL() throws {
        let request = try URLRequest
            .url("https://api.example.com/v1/users?page=1")
            .build()

        XCTAssertEqual(request.url?.query, "page=1")
    }

    // MARK: - Path Building

    func test_path_buildsRelativeURL() throws {
        let request = try URLRequest
            .path("data/users")
            .build()

        XCTAssertEqual(request.url?.path, "data/users")
    }

    func test_path_appendsWithSlash() throws {
        let request = try URLRequest
            .path("users")
            .path("123")
            .build()

        XCTAssertTrue(request.url?.absoluteString.contains("users/123") ?? false)
    }

    func test_path_handlesTrailingSlash() throws {
        let request = try URLRequest
            .path("users/")
            .path("123")
            .build()

        XCTAssertTrue(request.url?.absoluteString.contains("users/123") ?? false)
    }

    func test_path_handlesLeadingSlash() throws {
        let request = try URLRequest
            .path("users")
            .path("/123")
            .build()

        XCTAssertTrue(request.url?.absoluteString.contains("users/123") ?? false)
    }

    func test_path_handlesBothSlashes() throws {
        let request = try URLRequest
            .path("users/")
            .path("/123")
            .build()

        XCTAssertTrue(request.url?.absoluteString.contains("users/123") ?? false)
    }

    // MARK: - HTTP Methods

    func test_allHTTPMethods() throws {
        let methods: [URLRequest.Builder.HTTPMethod] = [.GET, .POST, .PUT, .PATCH, .DELETE]

        for method in methods {
            let request = try URLRequest
                .url("https://test.com")
                .method(method)
                .build()

            XCTAssertEqual(request.httpMethod, method.rawValue)
        }
    }

    // MARK: - Headers

    func test_headers_setsCorrectly() throws {
        let request = try URLRequest
            .url("https://test.com")
            .headers(key: "Content-Type", value: "application/json")
            .headers(key: "Authorization", value: "Bearer token")
            .build()

        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Bearer token")
    }

    // MARK: - Body

    func test_body_encodesEncodable() throws {
        struct Payload: Codable, Equatable {
            let name: String
        }

        let request = try URLRequest
            .url("https://test.com")
            .method(.POST)
            .body(Payload(name: "Den"))
            .build()

        XCTAssertNotNil(request.httpBody)
        let decoded = try JSONDecoder().decode(Payload.self, from: request.httpBody!)
        XCTAssertEqual(decoded.name, "Den")
    }

    func test_bodyRaw_setsDataDirectly() throws {
        let rawData = Data("raw".utf8)
        let request = try URLRequest
            .url("https://test.com")
            .method(.POST)
            .bodyRaw(rawData)
            .build()

        XCTAssertEqual(request.httpBody, rawData)
    }

    // MARK: - Query Parameters

    func test_queries_setsQueryItems() throws {
        let request = try URLRequest
            .url("https://test.com/api")
            .queries([
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "20"),
            ])
            .build()

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "1")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "limit", value: "20")))
    }

    func test_queriesEncodable_convertsToQueryItems() throws {
        struct Params: Encodable {
            let page: Int
            let limit: Int
        }

        let request = try URLRequest
            .url("https://test.com/api")
            .queriesEncodable(Params(page: 1, limit: 20))
            .build()

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "1" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "limit" && $0.value == "20" }))
    }

    func test_queriesEncodable_nil_clearsQueryItems() throws {
        let request = try URLRequest
            .url("https://test.com/api?existing=1")
            .queriesEncodable(nil)
            .build()

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        XCTAssertNil(components.queryItems)
    }

    // MARK: - URL Object

    func test_url_fromURLObject_preservesAllComponents() throws {
        let url = URL(string: "https://api.example.com:8080/v1/users?page=1&limit=20")!
        let request = try URLRequest.Builder.url(url).method(.GET).build()

        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.example.com")
        XCTAssertEqual(request.url?.port, 8080)
        XCTAssertEqual(request.url?.path, "/v1/users")
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "1")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "limit", value: "20")))
    }

    // MARK: - queriesEncodable Error

    func test_queriesEncodable_throwsOnNonDictionaryEncodable() {
        // Array encodes to JSON array, not dictionary — should throw
        let array = [1, 2, 3]
        XCTAssertThrowsError(
            try URLRequest
                .url("https://test.com")
                .queriesEncodable(array)
                .build()
        )
    }

    // MARK: - Bulk Headers

    func test_headers_bulkSetsCorrectly() throws {
        let request = try URLRequest
            .url("https://test.com")
            .headers([
                "Content-Type": "application/json",
                "Accept": "application/json",
                "X-Custom": "value"
            ])
            .build()

        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["Accept"], "application/json")
        XCTAssertEqual(request.allHTTPHeaderFields?["X-Custom"], "value")
    }

    func test_headers_bulkOverwritesExisting() throws {
        let request = try URLRequest
            .url("https://test.com")
            .headers(key: "Accept", value: "text/html")
            .headers(["Accept": "application/json"])
            .build()

        XCTAssertEqual(request.allHTTPHeaderFields?["Accept"], "application/json")
    }

    // MARK: - Timeout

    func test_timeout_setsTimeoutInterval() throws {
        let request = try URLRequest
            .url("https://test.com")
            .timeout(30.0)
            .build()

        XCTAssertEqual(request.timeoutInterval, 30.0)
    }

    func test_timeout_defaultIsSystemDefault() throws {
        let request = try URLRequest
            .url("https://test.com")
            .build()

        XCTAssertEqual(request.timeoutInterval, 60.0) // URLRequest default
    }

    // MARK: - Auto Content-Type

    func test_body_autoSetsContentTypeJSON() throws {
        struct Payload: Encodable { let name: String }
        let request = try URLRequest
            .url("https://test.com")
            .method(.POST)
            .body(Payload(name: "test"))
            .build()

        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }

    func test_body_doesNotOverrideExistingContentType() throws {
        struct Payload: Encodable { let name: String }
        let request = try URLRequest
            .url("https://test.com")
            .method(.POST)
            .headers(key: "Content-Type", value: "text/plain")
            .body(Payload(name: "test"))
            .build()

        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "text/plain")
    }

    // MARK: - URL from URL Object

    func test_url_fromURLObject_static() throws {
        let url = URL(string: "https://api.example.com/v1/users")!
        let request = try URLRequest.url(url).method(.GET).build()

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
    }

    // MARK: - Error

    func test_build_emptyPath_succeeds() {
        let builder = URLRequest.path("")
        XCTAssertNoThrow(try builder.build())
    }
}
