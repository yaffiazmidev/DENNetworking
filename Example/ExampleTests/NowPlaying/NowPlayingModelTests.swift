import XCTest
@testable import Example

final class NowPlayingModelTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - TMDBResponse

    func test_tmdbResponse_decodesFromJSON() throws {
        let data = NowPlayingFixtures.itemsJSON()
        let response = try decoder.decode(TMDBResponse.self, from: data)

        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.results?.count, 2)
    }

    func test_tmdbResponse_decodesEmptyResults() throws {
        let data = NowPlayingFixtures.emptyResultsJSON
        let response = try decoder.decode(TMDBResponse.self, from: data)

        XCTAssertEqual(response.results?.count, 0)
    }

    // MARK: - RemoteNowPlayingItem

    func test_remoteItem_decodesAllFields() throws {
        let data = NowPlayingFixtures.itemsJSON()
        let response = try decoder.decode(TMDBResponse.self, from: data)
        let item = try XCTUnwrap(response.results?.first)

        XCTAssertEqual(item.id, 1)
        XCTAssertEqual(item.title, "Test Movie 1")
        XCTAssertEqual(item.overview, "A great movie")
        XCTAssertEqual(item.posterPath, "/test.jpg")
        XCTAssertEqual(item.voteAverage, 7.5)
        XCTAssertEqual(item.releaseDate, "2025-01-01")
    }

    func test_remoteItem_handlesNullPosterPath() throws {
        let data = NowPlayingFixtures.itemsJSON()
        let response = try decoder.decode(TMDBResponse.self, from: data)
        let item = try XCTUnwrap(response.results?.last)

        XCTAssertNil(item.posterPath)
    }

    // MARK: - asViewModels mapping

    func test_asViewModels_mapsCorrectly() {
        let remote = [
            RemoteNowPlayingItem(id: 1, title: "Title", overview: "Overview", posterPath: "/p.jpg", voteAverage: 8.5, releaseDate: "2025-01-01"),
            RemoteNowPlayingItem(id: 2, title: "Title 2", overview: "Overview 2", posterPath: nil, voteAverage: 6.0, releaseDate: "2025-06-15")
        ]

        let viewModels = remote.asViewModels

        XCTAssertEqual(viewModels.count, 2)
        XCTAssertEqual(viewModels[0].id, 1)
        XCTAssertEqual(viewModels[0].title, "Title")
        XCTAssertEqual(viewModels[0].voteAverage, 8.5)
        XCTAssertEqual(viewModels[1].id, 2)
        XCTAssertEqual(viewModels[1].releaseDate, "2025-06-15")
    }

    func test_asViewModels_handlesNilFieldsWithDefaults() {
        let remote = [
            RemoteNowPlayingItem(id: nil, title: nil, overview: nil, posterPath: nil, voteAverage: nil, releaseDate: nil)
        ]

        let viewModels = remote.asViewModels

        XCTAssertEqual(viewModels[0].id, 0)
        XCTAssertEqual(viewModels[0].title, "")
        XCTAssertEqual(viewModels[0].overview, "")
        XCTAssertEqual(viewModels[0].voteAverage, 0)
        XCTAssertEqual(viewModels[0].releaseDate, "")
    }
}
