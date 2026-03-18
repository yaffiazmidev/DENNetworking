import XCTest
@testable import Example

final class TMDBEndpointTests: XCTestCase {

    // MARK: - Read: Popular (GET)

    func test_popular_buildsCorrectURL() throws {
        let request = try TMDBEndpoint.popular(page: 1).makeRequest()

        XCTAssertEqual(request.url?.host, "api.themoviedb.org")
        XCTAssertEqual(request.url?.path, "/3/movie/popular")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_popular_includesPageQuery() throws {
        let request = try TMDBEndpoint.popular(page: 3).makeRequest()
        let queryItems = queryItems(from: request)

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "3")))
    }

    // MARK: - Read: Movie Detail (GET)

    func test_movieDetail_buildsCorrectURL() throws {
        let request = try TMDBEndpoint.movieDetail(id: 550).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/movie/550")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    // MARK: - Read: Search (GET)

    func test_search_buildsCorrectURL() throws {
        let request = try TMDBEndpoint.search(query: "Batman", page: 1).makeRequest()

        XCTAssertEqual(request.url?.host, "api.themoviedb.org")
        XCTAssertEqual(request.url?.path, "/3/search/movie")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func test_search_includesQueryAndPage() throws {
        let request = try TMDBEndpoint.search(query: "Batman", page: 2).makeRequest()
        let queryItems = queryItems(from: request)

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "query", value: "Batman")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "2")))
    }

    // MARK: - Create: Rate Movie (POST)

    func test_rateMovie_buildsCorrectRequest() throws {
        let request = try TMDBEndpoint.rateMovie(id: 550, rating: 8.5).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/movie/550/rating")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    func test_rateMovie_bodyContainsRating() throws {
        let request = try TMDBEndpoint.rateMovie(id: 550, rating: 7.0).makeRequest()
        let body = try JSONDecoder().decode(RateMovieRequest.self, from: request.httpBody!)

        XCTAssertEqual(body.value, 7.0)
    }

    // MARK: - Create: Add to Watchlist (POST)

    func test_addToWatchlist_buildsCorrectRequest() throws {
        let request = try TMDBEndpoint.addToWatchlist(accountId: 123, movieId: 550).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/account/123/watchlist")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }

    func test_addToWatchlist_bodyContainsCorrectPayload() throws {
        let request = try TMDBEndpoint.addToWatchlist(accountId: 123, movieId: 550).makeRequest()
        let body = try JSONDecoder().decode(WatchlistRequest.self, from: request.httpBody!)

        XCTAssertEqual(body.mediaType, "movie")
        XCTAssertEqual(body.mediaId, 550)
        XCTAssertTrue(body.watchlist)
    }

    // MARK: - Update: Update Rating (PUT)

    func test_updateRating_buildsCorrectRequest() throws {
        let request = try TMDBEndpoint.updateRating(id: 550, rating: 9.0).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/movie/550/rating")
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json")
    }

    func test_updateRating_bodyContainsNewRating() throws {
        let request = try TMDBEndpoint.updateRating(id: 550, rating: 9.0).makeRequest()
        let body = try JSONDecoder().decode(RateMovieRequest.self, from: request.httpBody!)

        XCTAssertEqual(body.value, 9.0)
    }

    // MARK: - Update: Remove from Watchlist (PUT)

    func test_removeFromWatchlist_buildsCorrectRequest() throws {
        let request = try TMDBEndpoint.removeFromWatchlist(accountId: 123, movieId: 550).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/account/123/watchlist")
        XCTAssertEqual(request.httpMethod, "PUT")
    }

    func test_removeFromWatchlist_bodyHasWatchlistFalse() throws {
        let request = try TMDBEndpoint.removeFromWatchlist(accountId: 123, movieId: 550).makeRequest()
        let body = try JSONDecoder().decode(WatchlistRequest.self, from: request.httpBody!)

        XCTAssertEqual(body.mediaId, 550)
        XCTAssertFalse(body.watchlist)
    }

    // MARK: - Delete: Delete Rating (DELETE)

    func test_deleteRating_buildsCorrectRequest() throws {
        let request = try TMDBEndpoint.deleteRating(id: 550).makeRequest()

        XCTAssertEqual(request.url?.path, "/3/movie/550/rating")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertNil(request.httpBody)
    }

    // MARK: - Helper

    private func queryItems(from request: URLRequest) -> [URLQueryItem] {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
