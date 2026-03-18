import XCTest
@testable import Example

final class MovieDetailEndpointTests: XCTestCase {

    // MARK: - getDetail (GET)

    func test_getDetail_buildsCorrectPath() throws {
        let request = try MovieDetailEndpoint.getDetail(movieId: 550).makeRequest()

        XCTAssertEqual(request.url?.path, "movie/550")
    }

    func test_getDetail_defaultsToGET() throws {
        let request = try MovieDetailEndpoint.getDetail(movieId: 550).makeRequest()

        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_getDetail_hasNoQueryParams() throws {
        let request = try MovieDetailEndpoint.getDetail(movieId: 550).makeRequest()
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)

        XCTAssertNil(components?.queryItems)
    }

    func test_getDetail_hasNoBody() throws {
        let request = try MovieDetailEndpoint.getDetail(movieId: 550).makeRequest()

        XCTAssertNil(request.httpBody)
    }

    func test_getDetail_usesCorrectMovieId() throws {
        let request = try MovieDetailEndpoint.getDetail(movieId: 12345).makeRequest()

        XCTAssertEqual(request.url?.path, "movie/12345")
    }
}
