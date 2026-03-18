import XCTest
import DENNetworking
@testable import Example

@MainActor
final class MovieDetailViewModelTests: XCTestCase {

    private func makeViewModel(
        movieId: Int = 1,
        data: Data,
        statusCode: Int = 200
    ) -> MovieDetailViewModel {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let service = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        let repository = TMDBRepository(service: service)
        return MovieDetailViewModel(movieId: movieId, repository: repository)
    }

    private func makeFailingViewModel(
        movieId: Int = 1,
        error: DENNetworkError
    ) -> MovieDetailViewModel {
        let client = MockHTTPClient.failure(error)
        let service = DENNetworkService(client: client)
        let repository = TMDBRepository(service: service)
        return MovieDetailViewModel(movieId: movieId, repository: repository)
    }

    // MARK: - Read (GET)

    func test_loadDetail_setsDetail() async {
        let sut = makeViewModel(data: TMDBFixtures.movieDetailJSON())

        await sut.loadDetail()

        XCTAssertNotNil(sut.detail)
        XCTAssertEqual(sut.detail?.title, "Test Movie")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadDetail_setsNotFoundError() async {
        let sut = makeFailingViewModel(error: .notFound)

        await sut.loadDetail()

        XCTAssertNil(sut.detail)
        XCTAssertEqual(sut.errorMessage, "Movie not found.")
    }

    func test_loadDetail_setsNotConnectedError() async {
        let sut = makeFailingViewModel(error: .notConnected)

        await sut.loadDetail()

        XCTAssertEqual(sut.errorMessage, "No internet connection.")
    }

    // MARK: - Create: rateMovie (POST)

    func test_rateMovie_setsSuccessMessage() async {
        let sut = makeViewModel(data: TMDBFixtures.statusResponseJSON(statusCode: 1, message: "Success."))

        await sut.rateMovie()

        XCTAssertEqual(sut.successMessage, "Success.")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isActioning)
    }

    func test_rateMovie_setsErrorOnUnauthorized() async {
        let sut = makeFailingViewModel(error: .unauthorized)

        await sut.rateMovie()

        XCTAssertEqual(sut.errorMessage, "Authentication required. Please log in.")
        XCTAssertNil(sut.successMessage)
    }

    // MARK: - Create: addToWatchlist (POST)

    func test_addToWatchlist_setsSuccessAndUpdatesState() async {
        let sut = makeViewModel(data: TMDBFixtures.statusResponseJSON(statusCode: 1, message: "Success."))
        XCTAssertFalse(sut.isInWatchlist)

        await sut.addToWatchlist()

        XCTAssertTrue(sut.isInWatchlist)
        XCTAssertEqual(sut.successMessage, "Success.")
    }

    func test_addToWatchlist_setsErrorOnFailure() async {
        let sut = makeFailingViewModel(error: .serverError(statusCode: 500))

        await sut.addToWatchlist()

        XCTAssertFalse(sut.isInWatchlist)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Update: updateRating (PUT)

    func test_updateRating_setsSuccessMessage() async {
        let sut = makeViewModel(data: TMDBFixtures.statusResponseJSON(statusCode: 12, message: "Updated."))
        sut.userRating = 9.0

        await sut.updateRating()

        XCTAssertEqual(sut.successMessage, "Updated.")
        XCTAssertNil(sut.errorMessage)
    }

    func test_updateRating_setsErrorOnNotFound() async {
        let sut = makeFailingViewModel(error: .notFound)

        await sut.updateRating()

        XCTAssertEqual(sut.errorMessage, "Movie not found.")
    }

    // MARK: - Update: removeFromWatchlist (PUT)

    func test_removeFromWatchlist_setsSuccessAndUpdatesState() async {
        let sut = makeViewModel(data: TMDBFixtures.statusResponseJSON(statusCode: 13, message: "Removed."))
        sut.isInWatchlist = true

        await sut.removeFromWatchlist()

        XCTAssertFalse(sut.isInWatchlist)
        XCTAssertEqual(sut.successMessage, "Removed.")
    }

    // MARK: - Delete: deleteRating (DELETE)

    func test_deleteRating_setsSuccessAndResetsRating() async {
        let client = MockHTTPClient.success(data: Data(), statusCode: 200)
        let service = DENNetworkService(client: client)
        let repository = TMDBRepository(service: service)
        let sut = MovieDetailViewModel(movieId: 1, repository: repository)
        sut.userRating = 8.0

        await sut.deleteRating()

        XCTAssertEqual(sut.successMessage, "Rating deleted.")
        XCTAssertEqual(sut.userRating, 5.0)
        XCTAssertFalse(sut.isActioning)
    }

    func test_deleteRating_setsErrorOnUnauthorized() async {
        let sut = makeFailingViewModel(error: .unauthorized)

        await sut.deleteRating()

        XCTAssertEqual(sut.errorMessage, "Authentication required. Please log in.")
        XCTAssertNil(sut.successMessage)
    }
}
