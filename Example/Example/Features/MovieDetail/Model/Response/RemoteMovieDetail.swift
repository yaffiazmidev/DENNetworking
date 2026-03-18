import Foundation

struct RemoteMovieDetail: Decodable, Sendable {
    let id: Int?
    let title: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let releaseDate: String?
    let runtime: Int?
    let status: String?
    let tagline: String?
    let genres: [RemoteGenre]?

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, status, tagline, genres
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
    }
}

struct RemoteGenre: Decodable, Sendable {
    let id: Int?
    let name: String?
}
