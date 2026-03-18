import XCTest
import DENNetworking
@testable import Example

final class NowPlayingServiceTests: XCTestCase {

    private func makeService(data: Data, statusCode: Int = 200) -> NowPlayingService {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let networkService = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        return NowPlayingService(networkService: networkService)
    }

    private func makeFailingService(error: DENNetworkError) -> NowPlayingService {
        let client = MockHTTPClient.failure(error)
        let networkService = DENNetworkService(client: client)
        return NowPlayingService(networkService: networkService)
    }

    // MARK: - getItems

    func test_getItems_decodesResponse() async throws {
        let sut = makeService(data: NowPlayingFixtures.itemsJSON())

        let items = try await sut.getItems()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].id, 1)
        XCTAssertEqual(items[0].title, "Test Movie 1")
        XCTAssertEqual(items[0].voteAverage, 7.5)
        XCTAssertEqual(items[1].id, 2)
        XCTAssertEqual(items[1].title, "Test Movie 2")
    }

    func test_getItems_emptyResults() async throws {
        let sut = makeService(data: NowPlayingFixtures.emptyResultsJSON)

        let items = try await sut.getItems()

        XCTAssertTrue(items.isEmpty)
    }

    func test_getItems_throwsOnServerError() async {
        let sut = makeFailingService(error: .serverError(statusCode: 500))

        do {
            _ = try await sut.getItems()
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .serverError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_getItems_throwsOnNotConnected() async {
        let sut = makeFailingService(error: .notConnected)

        do {
            _ = try await sut.getItems()
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
