import Foundation
import DENNetworking

enum TMDBEndpoint {

    // MARK: - Read
    case popular(page: Int)
    case movieDetail(id: Int)
    case search(query: String, page: Int)

    // MARK: - Create
    case rateMovie(id: Int, rating: Double)
    case addToWatchlist(accountId: Int, movieId: Int)

    // MARK: - Update
    case updateRating(id: Int, rating: Double)
    case removeFromWatchlist(accountId: Int, movieId: Int)

    // MARK: - Delete
    case deleteRating(id: Int)

    func makeRequest() throws -> URLRequest {
        switch self {

        // MARK: Read (GET)

        case .popular(let page):
            return try URLRequest
                .url("https://api.themoviedb.org/3/movie/popular")
                .method(.GET)
                .queries([URLQueryItem(name: "page", value: "\(page)")])
                .build()

        case .movieDetail(let id):
            return try URLRequest
                .url("https://api.themoviedb.org/3/movie/\(id)")
                .method(.GET)
                .build()

        case .search(let query, let page):
            return try URLRequest
                .url("https://api.themoviedb.org/3/search/movie")
                .method(.GET)
                .queries([
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "page", value: "\(page)"),
                ])
                .build()

        // MARK: Create (POST)

        case .rateMovie(let id, let rating):
            return try URLRequest
                .url("https://api.themoviedb.org/3/movie/\(id)/rating")
                .method(.POST)
                .headers(key: "Content-Type", value: "application/json")
                .body(RateMovieRequest(value: rating))
                .build()

        case .addToWatchlist(let accountId, let movieId):
            return try URLRequest
                .url("https://api.themoviedb.org/3/account/\(accountId)/watchlist")
                .method(.POST)
                .headers(key: "Content-Type", value: "application/json")
                .body(WatchlistRequest(mediaType: "movie", mediaId: movieId, watchlist: true))
                .build()

        // MARK: Update (PUT)

        case .updateRating(let id, let rating):
            return try URLRequest
                .url("https://api.themoviedb.org/3/movie/\(id)/rating")
                .method(.PUT)
                .headers(key: "Content-Type", value: "application/json")
                .body(RateMovieRequest(value: rating))
                .build()

        case .removeFromWatchlist(let accountId, let movieId):
            return try URLRequest
                .url("https://api.themoviedb.org/3/account/\(accountId)/watchlist")
                .method(.PUT)
                .headers(key: "Content-Type", value: "application/json")
                .body(WatchlistRequest(mediaType: "movie", mediaId: movieId, watchlist: false))
                .build()

        // MARK: Delete (DELETE)

        case .deleteRating(let id):
            return try URLRequest
                .url("https://api.themoviedb.org/3/movie/\(id)/rating")
                .method(.DELETE)
                .build()
        }
    }
}
