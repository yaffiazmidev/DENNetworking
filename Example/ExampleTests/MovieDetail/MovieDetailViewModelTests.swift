import XCTest
import DENNetworking
@testable import Example

@MainActor
final class MovieDetailViewModelTests: XCTestCase {

    private func makeSUT(data: Data, statusCode: Int = 200, movieId: Int = 550) -> MovieDetailViewModel {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let service = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        let movieDetailService = MovieDetailService(networkService: service)
        return MovieDetailViewModel(movieId: movieId, movieDetailService: movieDetailService)
    }

    private func makeFailingSUT(error: DENNetworkError, movieId: Int = 550) -> MovieDetailViewModel {
        let client = MockHTTPClient.failure(error)
        let service = DENNetworkService(client: client)
        let movieDetailService = MovieDetailService(networkService: service)
        return MovieDetailViewModel(movieId: movieId, movieDetailService: movieDetailService)
    }

    // MARK: - loadData

    func test_loadData_setsDetail() async {
        let sut = makeSUT(data: MovieDetailFixtures.detailJSON())

        await sut.loadData()

        XCTAssertNotNil(sut.detail)
        XCTAssertEqual(sut.detail?.title, "Test Movie")
        XCTAssertEqual(sut.detail?.runtime, "2h 22m")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadData_setsErrorOnNotConnected() async {
        let sut = makeFailingSUT(error: .notConnected)

        await sut.loadData()

        XCTAssertNil(sut.detail)
        XCTAssertEqual(sut.errorMessage, "No internet connection.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadData_setsErrorOnNotFound() async {
        let sut = makeFailingSUT(error: .notFound)

        await sut.loadData()

        XCTAssertNil(sut.detail)
        XCTAssertEqual(sut.errorMessage, "Movie not found.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadData_setsTimeoutError() async {
        let sut = makeFailingSUT(error: .timeout)

        await sut.loadData()

        XCTAssertEqual(sut.errorMessage, "Request timed out. Please try again.")
    }
}
