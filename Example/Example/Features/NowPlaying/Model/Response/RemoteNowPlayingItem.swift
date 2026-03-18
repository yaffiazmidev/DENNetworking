import Foundation

struct TMDBResponse: Decodable, Sendable {
    let page: Int?
    let results: [RemoteNowPlayingItem]?
}

struct RemoteNowPlayingItem: Decodable, Sendable {
    let id: Int?
    let title: String?
    let overview: String?
    let posterPath: String?
    let voteAverage: Double?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
    }
}
