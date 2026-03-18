import XCTest
@testable import Example

final class TMDBModelsTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Movie

    func test_movie_posterURL_withPath() {
        let movie = makeMovie(posterPath: "/abc.jpg")
        XCTAssertEqual(movie.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }

    func test_movie_posterURL_nilWhenNoPosterPath() {
        let movie = makeMovie(posterPath: nil)
        XCTAssertNil(movie.posterURL)
    }

    func test_movie_backdropURL_withPath() {
        let movie = makeMovie(backdropPath: "/bg.jpg")
        XCTAssertEqual(movie.backdropURL?.absoluteString, "https://image.tmdb.org/t/p/w780/bg.jpg")
    }

    func test_movie_ratingText_formatsCorrectly() {
        let movie = makeMovie(voteAverage: 8.567)
        XCTAssertEqual(movie.ratingText, "8.6")
    }

    func test_movie_decodesFromJSON() throws {
        let data = TMDBFixtures.popularMoviesJSON()
        let response = try decoder.decode(TMDBResponse<Movie>.self, from: data)

        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results[0].id, 1)
        XCTAssertEqual(response.results[0].releaseDate, "2025-01-01")
    }

    // MARK: - MovieDetail

    func test_movieDetail_runtimeText_hoursAndMinutes() {
        let detail = makeMovieDetail(runtime: 142)
        XCTAssertEqual(detail.runtimeText, "2h 22m")
    }

    func test_movieDetail_runtimeText_minutesOnly() {
        let detail = makeMovieDetail(runtime: 45)
        XCTAssertEqual(detail.runtimeText, "45m")
    }

    func test_movieDetail_runtimeText_nilWhenZero() {
        let detail = makeMovieDetail(runtime: 0)
        XCTAssertNil(detail.runtimeText)
    }

    func test_movieDetail_runtimeText_nilWhenNil() {
        let detail = makeMovieDetail(runtime: nil)
        XCTAssertNil(detail.runtimeText)
    }

    func test_movieDetail_genreText() {
        let detail = makeMovieDetail(genres: [
            Genre(id: 1, name: "Action"),
            Genre(id: 2, name: "Comedy"),
        ])
        XCTAssertEqual(detail.genreText, "Action, Comedy")
    }

    func test_movieDetail_genreText_empty() {
        let detail = makeMovieDetail(genres: [])
        XCTAssertEqual(detail.genreText, "")
    }

    func test_movieDetail_decodesFromJSON() throws {
        let data = TMDBFixtures.movieDetailJSON()
        let detail = try decoder.decode(MovieDetail.self, from: data)

        XCTAssertEqual(detail.title, "Test Movie")
        XCTAssertEqual(detail.runtime, 120)
        XCTAssertEqual(detail.genres.count, 2)
        XCTAssertEqual(detail.tagline, "Testing is fun")
    }

    // MARK: - Helpers

    private func makeMovie(
        posterPath: String? = "/test.jpg",
        backdropPath: String? = "/bg.jpg",
        voteAverage: Double = 7.5
    ) -> Movie {
        Movie(
            id: 1,
            title: "Test",
            overview: "Overview",
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: 100,
            releaseDate: "2025-01-01",
            popularity: 50.0
        )
    }

    private func makeMovieDetail(
        runtime: Int? = 120,
        genres: [Genre] = [Genre(id: 1, name: "Action")]
    ) -> MovieDetail {
        MovieDetail(
            id: 1,
            title: "Test",
            overview: "Overview",
            posterPath: "/test.jpg",
            backdropPath: "/bg.jpg",
            voteAverage: 8.0,
            voteCount: 500,
            releaseDate: "2025-01-01",
            runtime: runtime,
            genres: genres,
            status: "Released",
            tagline: "Tagline"
        )
    }
}
