import XCTest
@testable import Example

final class NowPlayingEndpointTests: XCTestCase {

    // MARK: - getItems (GET)

    func test_getItems_buildsCorrectPath() throws {
        let request = try NowPlayingEndpoint.getItems().makeRequest()

        XCTAssertEqual(request.url?.path, "movie/now_playing")
    }

    func test_getItems_defaultsToGET() throws {
        let request = try NowPlayingEndpoint.getItems().makeRequest()

        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_getItems_includesPageQuery() throws {
        let request = try NowPlayingEndpoint.getItems(page: 3).makeRequest()
        let queryItems = queryItems(from: request)

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "3")))
    }

    func test_getItems_defaultPageIsOne() throws {
        let request = try NowPlayingEndpoint.getItems().makeRequest()
        let queryItems = queryItems(from: request)

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "1")))
    }

    func test_getItems_hasNoBody() throws {
        let request = try NowPlayingEndpoint.getItems().makeRequest()

        XCTAssertNil(request.httpBody)
    }

    // MARK: - Helper

    private func queryItems(from request: URLRequest) -> [URLQueryItem] {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
