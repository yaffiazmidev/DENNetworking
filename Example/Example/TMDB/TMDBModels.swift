import Foundation

// MARK: - API Response Wrapper

struct TMDBResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let results: [T]
    let totalPages: Int
    let totalResults: Int
}

// MARK: - Movie

struct Movie: Decodable, Sendable, Identifiable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let releaseDate: String?
    let popularity: Double

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
    }

    var ratingText: String {
        String(format: "%.1f", voteAverage)
    }
}

// MARK: - Movie Detail

struct MovieDetail: Decodable, Sendable, Identifiable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let releaseDate: String?
    let runtime: Int?
    let genres: [Genre]
    let status: String
    let tagline: String?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    var runtimeText: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var genreText: String {
        genres.map(\.name).joined(separator: ", ")
    }
}

struct Genre: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
}

// MARK: - CRUD Request/Response Models

/// POST /movie/{id}/rating — Request body
struct RateMovieRequest: Encodable, Sendable {
    let value: Double
}

/// POST /account/{id}/watchlist — Request body
struct WatchlistRequest: Encodable, Sendable {
    let mediaType: String
    let mediaId: Int
    let watchlist: Bool
}

/// Generic TMDB mutation response (Create / Update / Delete)
struct TMDBStatusResponse: Decodable, Sendable {
    let statusCode: Int
    let statusMessage: String
}
