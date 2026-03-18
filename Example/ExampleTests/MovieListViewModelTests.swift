import XCTest
import DENNetworking
@testable import Example

@MainActor
final class MovieListViewModelTests: XCTestCase {

    private func makeViewModel(data: Data, statusCode: Int = 200) -> MovieListViewModel {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let service = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        let repository = TMDBRepository(service: service)
        return MovieListViewModel(repository: repository)
    }

    private func makeFailingViewModel(error: DENNetworkError) -> MovieListViewModel {
        let client = MockHTTPClient.failure(error)
        let service = DENNetworkService(client: client)
        let repository = TMDBRepository(service: service)
        return MovieListViewModel(repository: repository)
    }

    // MARK: - loadPopularMovies

    func test_loadPopularMovies_setsMovies() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON())

        await sut.loadPopularMovies()

        XCTAssertEqual(sut.movies.count, 2)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadPopularMovies_setsErrorOnFailure() async {
        let sut = makeFailingViewModel(error: .notConnected)

        await sut.loadPopularMovies()

        XCTAssertTrue(sut.movies.isEmpty)
        XCTAssertEqual(sut.errorMessage, "No internet connection.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadPopularMovies_setsTimeoutError() async {
        let sut = makeFailingViewModel(error: .timeout)

        await sut.loadPopularMovies()

        XCTAssertEqual(sut.errorMessage, "Request timed out. Try again.")
    }

    // MARK: - search

    func test_search_setsSearchResults() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON())
        sut.searchText = "Test"

        await sut.search()

        XCTAssertEqual(sut.searchResults.count, 2)
        XCTAssertFalse(sut.isLoading)
    }

    func test_search_emptyQuery_clearsResults() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON())
        sut.searchText = "   "

        await sut.search()

        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    // MARK: - displayedMovies

    func test_displayedMovies_showsMoviesWhenNoSearch() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON())

        await sut.loadPopularMovies()

        XCTAssertEqual(sut.displayedMovies.count, 2)
    }

    func test_displayedMovies_showsSearchResultsWhenSearching() async {
        let sut = makeViewModel(data: TMDBFixtures.emptyResultsJSON)
        sut.searchText = "query"

        await sut.search()

        XCTAssertTrue(sut.displayedMovies.isEmpty)
    }

    // MARK: - hasMorePages

    func test_hasMorePages_trueWhenMorePagesExist() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON(page: 1, totalPages: 5))

        await sut.loadPopularMovies()

        XCTAssertTrue(sut.hasMorePages)
    }

    func test_hasMorePages_falseOnLastPage() async {
        let sut = makeViewModel(data: TMDBFixtures.popularMoviesJSON(page: 1, totalPages: 1))

        await sut.loadPopularMovies()

        XCTAssertFalse(sut.hasMorePages)
    }
}
