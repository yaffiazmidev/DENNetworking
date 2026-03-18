import XCTest
import DENNetworking
@testable import Example

final class TMDBRepositoryTests: XCTestCase {

    private func makeService(data: Data, statusCode: Int = 200) -> DENNetworkingServiceProtocol {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        return DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
    }

    private func makeVoidService(statusCode: Int = 200) -> DENNetworkingServiceProtocol {
        let client = MockHTTPClient.success(data: Data(), statusCode: statusCode)
        return DENNetworkService(client: client)
    }

    private func makeFailingService(error: DENNetworkError) -> DENNetworkingServiceProtocol {
        let client = MockHTTPClient.failure(error)
        return DENNetworkService(client: client)
    }

    // MARK: - Create: rateMovie (POST)

    func test_rateMovie_decodesStatusResponse() async throws {
        let service = makeService(data: TMDBFixtures.statusResponseJSON(statusCode: 1, message: "Success."))
        let sut = TMDBRepository(service: service)

        let response = try await sut.rateMovie(id: 550, rating: 8.5)

        XCTAssertEqual(response.statusCode, 1)
        XCTAssertEqual(response.statusMessage, "Success.")
    }

    func test_rateMovie_throwsUnauthorizedWithoutSession() async {
        let service = makeFailingService(error: .unauthorized)
        let sut = TMDBRepository(service: service)

        do {
            _ = try await sut.rateMovie(id: 550, rating: 8.5)
            XCTFail("Expected unauthorized error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Create: addToWatchlist (POST)

    func test_addToWatchlist_decodesStatusResponse() async throws {
        let service = makeService(data: TMDBFixtures.statusResponseJSON(statusCode: 1, message: "Success."))
        let sut = TMDBRepository(service: service)

        let response = try await sut.addToWatchlist(accountId: 123, movieId: 550)

        XCTAssertEqual(response.statusCode, 1)
    }

    func test_addToWatchlist_throwsOnServerError() async {
        let service = makeFailingService(error: .serverError(statusCode: 500))
        let sut = TMDBRepository(service: service)

        do {
            _ = try await sut.addToWatchlist(accountId: 123, movieId: 550)
            XCTFail("Expected server error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Read: fetchPopularMovies (GET)

    func test_fetchPopularMovies_decodesResponse() async throws {
        let service = makeService(data: TMDBFixtures.popularMoviesJSON())
        let sut = TMDBRepository(service: service)

        let response = try await sut.fetchPopularMovies(page: 1)

        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results[0].title, "Test Movie")
        XCTAssertEqual(response.results[0].voteAverage, 8.5)
        XCTAssertEqual(response.results[1].title, "Another Movie")
        XCTAssertNil(response.results[1].posterPath)
    }

    func test_fetchPopularMovies_emptyResults() async throws {
        let service = makeService(data: TMDBFixtures.emptyResultsJSON)
        let sut = TMDBRepository(service: service)

        let response = try await sut.fetchPopularMovies()

        XCTAssertEqual(response.results.count, 0)
        XCTAssertEqual(response.totalResults, 0)
    }

    func test_fetchPopularMovies_throwsOnServerError() async {
        let service = makeFailingService(error: .serverError(statusCode: 500))
        let sut = TMDBRepository(service: service)

        do {
            _ = try await sut.fetchPopularMovies()
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Read: fetchMovieDetail (GET)

    func test_fetchMovieDetail_decodesResponse() async throws {
        let service = makeService(data: TMDBFixtures.movieDetailJSON(id: 550))
        let sut = TMDBRepository(service: service)

        let detail = try await sut.fetchMovieDetail(id: 550)

        XCTAssertEqual(detail.title, "Test Movie")
        XCTAssertEqual(detail.runtime, 120)
        XCTAssertEqual(detail.genres.count, 2)
        XCTAssertEqual(detail.genres[0].name, "Action")
        XCTAssertEqual(detail.tagline, "Testing is fun")
    }

    func test_fetchMovieDetail_throwsNotFoundOn404() async {
        let service = makeFailingService(error: .notFound)
        let sut = TMDBRepository(service: service)

        do {
            _ = try await sut.fetchMovieDetail(id: 999999)
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Read: searchMovies (GET)

    func test_searchMovies_decodesResponse() async throws {
        let service = makeService(data: TMDBFixtures.popularMoviesJSON())
        let sut = TMDBRepository(service: service)

        let response = try await sut.searchMovies(query: "Test")

        XCTAssertEqual(response.results.count, 2)
    }

    func test_searchMovies_emptyResults() async throws {
        let service = makeService(data: TMDBFixtures.emptyResultsJSON)
        let sut = TMDBRepository(service: service)

        let response = try await sut.searchMovies(query: "nonexistent")

        XCTAssertEqual(response.results.count, 0)
    }

    // MARK: - Update: updateRating (PUT)

    func test_updateRating_decodesStatusResponse() async throws {
        let service = makeService(data: TMDBFixtures.statusResponseJSON(statusCode: 12, message: "The item/record was updated successfully."))
        let sut = TMDBRepository(service: service)

        let response = try await sut.updateRating(id: 550, rating: 9.0)

        XCTAssertEqual(response.statusCode, 12)
        XCTAssertEqual(response.statusMessage, "The item/record was updated successfully.")
    }

    func test_updateRating_throwsNotFoundForInvalidMovie() async {
        let service = makeFailingService(error: .notFound)
        let sut = TMDBRepository(service: service)

        do {
            _ = try await sut.updateRating(id: 0, rating: 5.0)
            XCTFail("Expected not found error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update: removeFromWatchlist (PUT)

    func test_removeFromWatchlist_decodesStatusResponse() async throws {
        let service = makeService(data: TMDBFixtures.statusResponseJSON(statusCode: 13, message: "The item/record was deleted successfully."))
        let sut = TMDBRepository(service: service)

        let response = try await sut.removeFromWatchlist(accountId: 123, movieId: 550)

        XCTAssertEqual(response.statusCode, 13)
    }

    // MARK: - Delete: deleteRating (DELETE → void)

    func test_deleteRating_succeedsWithNoBody() async throws {
        let service = makeVoidService(statusCode: 200)
        let sut = TMDBRepository(service: service)

        try await sut.deleteRating(id: 550)
        // No throw = success
    }

    func test_deleteRating_throwsNotFoundForUnratedMovie() async {
        let service = makeFailingService(error: .notFound)
        let sut = TMDBRepository(service: service)

        do {
            try await sut.deleteRating(id: 999)
            XCTFail("Expected not found error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_deleteRating_throwsUnauthorized() async {
        let service = makeFailingService(error: .unauthorized)
        let sut = TMDBRepository(service: service)

        do {
            try await sut.deleteRating(id: 550)
            XCTFail("Expected unauthorized error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
