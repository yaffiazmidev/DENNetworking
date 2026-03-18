import XCTest
@testable import Example

final class MovieDetailModelTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - RemoteMovieDetail

    func test_remoteMovieDetail_decodesAllFields() throws {
        let data = MovieDetailFixtures.detailJSON()
        let detail = try decoder.decode(RemoteMovieDetail.self, from: data)

        XCTAssertEqual(detail.id, 550)
        XCTAssertEqual(detail.title, "Test Movie")
        XCTAssertEqual(detail.overview, "A great movie about testing")
        XCTAssertEqual(detail.posterPath, "/test.jpg")
        XCTAssertEqual(detail.backdropPath, "/backdrop.jpg")
        XCTAssertEqual(detail.voteAverage, 8.5)
        XCTAssertEqual(detail.voteCount, 1000)
        XCTAssertEqual(detail.releaseDate, "2025-01-01")
        XCTAssertEqual(detail.runtime, 142)
        XCTAssertEqual(detail.status, "Released")
        XCTAssertEqual(detail.tagline, "Testing is fun")
        XCTAssertEqual(detail.genres?.count, 2)
    }

    func test_remoteMovieDetail_handlesNullFields() throws {
        let data = MovieDetailFixtures.detailWithoutRuntimeJSON()
        let detail = try decoder.decode(RemoteMovieDetail.self, from: data)

        XCTAssertNil(detail.runtime)
        XCTAssertNil(detail.posterPath)
        XCTAssertNil(detail.backdropPath)
        XCTAssertEqual(detail.genres?.count, 0)
    }

    // MARK: - RemoteGenre

    func test_genre_decodesCorrectly() throws {
        let data = MovieDetailFixtures.detailJSON()
        let detail = try decoder.decode(RemoteMovieDetail.self, from: data)
        let genre = try XCTUnwrap(detail.genres?.first)

        XCTAssertEqual(genre.id, 28)
        XCTAssertEqual(genre.name, "Action")
    }

    // MARK: - asViewModel mapping

    func test_asViewModel_mapsCorrectly() throws {
        let data = MovieDetailFixtures.detailJSON()
        let detail = try decoder.decode(RemoteMovieDetail.self, from: data)
        let viewModel = detail.asViewModel

        XCTAssertEqual(viewModel.id, 550)
        XCTAssertEqual(viewModel.title, "Test Movie")
        XCTAssertEqual(viewModel.tagline, "Testing is fun")
        XCTAssertEqual(viewModel.ratingText, "8.5")
        XCTAssertEqual(viewModel.runtime, "2h 22m")
        XCTAssertEqual(viewModel.genres, "Action, Adventure")
    }

    func test_asViewModel_handlesNilRuntime() throws {
        let data = MovieDetailFixtures.detailWithoutRuntimeJSON()
        let detail = try decoder.decode(RemoteMovieDetail.self, from: data)
        let viewModel = detail.asViewModel

        XCTAssertNil(viewModel.runtime)
        XCTAssertEqual(viewModel.genres, "")
    }

    func test_asViewModel_runtimeMinutesOnly() {
        let detail = RemoteMovieDetail(
            id: 1, title: "T", overview: "O", posterPath: nil, backdropPath: nil,
            voteAverage: 5, voteCount: 10, releaseDate: "2025-01-01",
            runtime: 45, status: "Released", tagline: "", genres: []
        )
        let viewModel = detail.asViewModel

        XCTAssertEqual(viewModel.runtime, "45m")
    }

    func test_asViewModel_runtimeZero() {
        let detail = RemoteMovieDetail(
            id: 1, title: "T", overview: "O", posterPath: nil, backdropPath: nil,
            voteAverage: 5, voteCount: 10, releaseDate: "2025-01-01",
            runtime: 0, status: "Released", tagline: "", genres: []
        )
        let viewModel = detail.asViewModel

        XCTAssertNil(viewModel.runtime)
    }
}
