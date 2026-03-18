import XCTest
import DENNetworking
@testable import Example

@MainActor
final class NowPlayingViewModelTests: XCTestCase {

    private func makeSUT(data: Data, statusCode: Int = 200) -> NowPlayingViewModel {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let service = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        let nowPlayingService = NowPlayingService(networkService: service)
        return NowPlayingViewModel(nowPlayingService: nowPlayingService)
    }

    private func makeFailingSUT(error: DENNetworkError) -> NowPlayingViewModel {
        let client = MockHTTPClient.failure(error)
        let service = DENNetworkService(client: client)
        let nowPlayingService = NowPlayingService(networkService: service)
        return NowPlayingViewModel(nowPlayingService: nowPlayingService)
    }

    // MARK: - loadData

    func test_loadData_setsItems() async {
        let sut = makeSUT(data: NowPlayingFixtures.itemsJSON())

        await sut.loadData()

        XCTAssertEqual(sut.items.count, 2)
        XCTAssertEqual(sut.items.first?.title, "Test Movie 1")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadData_setsErrorOnNotConnected() async {
        let sut = makeFailingSUT(error: .notConnected)

        await sut.loadData()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, "No internet connection.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadData_setsTimeoutError() async {
        let sut = makeFailingSUT(error: .timeout)

        await sut.loadData()

        XCTAssertEqual(sut.errorMessage, "Request timed out. Please try again.")
    }
}
