import XCTest
import DENNetworking
@testable import Example

final class MovieDetailServiceTests: XCTestCase {

    private func makeService(data: Data, statusCode: Int = 200) -> MovieDetailService {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = MockHTTPClient.success(data: data, statusCode: statusCode)
        let networkService = DENNetworkService(client: client, decoder: JSONResponseDecoder(decoder: decoder))
        return MovieDetailService(networkService: networkService)
    }

    private func makeFailingService(error: DENNetworkError) -> MovieDetailService {
        let client = MockHTTPClient.failure(error)
        let networkService = DENNetworkService(client: client)
        return MovieDetailService(networkService: networkService)
    }

    // MARK: - getDetail

    func test_getDetail_decodesResponse() async throws {
        let sut = makeService(data: MovieDetailFixtures.detailJSON())

        let detail = try await sut.getDetail(movieId: 550)

        XCTAssertEqual(detail.id, 550)
        XCTAssertEqual(detail.title, "Test Movie")
        XCTAssertEqual(detail.runtime, 142)
        XCTAssertEqual(detail.genres?.count, 2)
        XCTAssertEqual(detail.genres?.first?.name, "Action")
    }

    func test_getDetail_throwsOnNotFound() async {
        let sut = makeFailingService(error: .notFound)

        do {
            _ = try await sut.getDetail(movieId: 999999)
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_getDetail_throwsOnNotConnected() async {
        let sut = makeFailingService(error: .notConnected)

        do {
            _ = try await sut.getDetail(movieId: 550)
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
