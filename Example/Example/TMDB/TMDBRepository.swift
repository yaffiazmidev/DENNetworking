import Foundation
import DENNetworking

/// Repository that exposes typed async methods for TMDB endpoints.
///
/// Demonstrates full CRUD operations using DENNetworking:
/// - **Create**: Rate a movie, add to watchlist (POST)
/// - **Read**: Fetch popular movies, movie detail, search (GET)
/// - **Update**: Update rating, remove from watchlist (PUT)
/// - **Delete**: Delete rating (DELETE → void response)
final class TMDBRepository: Sendable {

    private let service: DENNetworkingServiceProtocol

    init(service: DENNetworkingServiceProtocol) {
        self.service = service
    }

    // MARK: - Create (POST)

    /// Rate a movie (1.0 - 10.0). Returns TMDB status response.
    func rateMovie(id: Int, rating: Double) async throws -> TMDBStatusResponse {
        let request = try TMDBEndpoint.rateMovie(id: id, rating: rating).makeRequest()
        return try await service.execute(request)
    }

    /// Add a movie to the user's watchlist.
    func addToWatchlist(accountId: Int, movieId: Int) async throws -> TMDBStatusResponse {
        let request = try TMDBEndpoint.addToWatchlist(accountId: accountId, movieId: movieId).makeRequest()
        return try await service.execute(request)
    }

    // MARK: - Read (GET)

    func fetchPopularMovies(page: Int = 1) async throws -> TMDBResponse<Movie> {
        let request = try TMDBEndpoint.popular(page: page).makeRequest()
        return try await service.execute(request)
    }

    func fetchMovieDetail(id: Int) async throws -> MovieDetail {
        let request = try TMDBEndpoint.movieDetail(id: id).makeRequest()
        return try await service.execute(request)
    }

    func searchMovies(query: String, page: Int = 1) async throws -> TMDBResponse<Movie> {
        let request = try TMDBEndpoint.search(query: query, page: page).makeRequest()
        return try await service.execute(request)
    }

    // MARK: - Update (PUT)

    /// Update an existing movie rating.
    func updateRating(id: Int, rating: Double) async throws -> TMDBStatusResponse {
        let request = try TMDBEndpoint.updateRating(id: id, rating: rating).makeRequest()
        return try await service.execute(request)
    }

    /// Remove a movie from the user's watchlist.
    func removeFromWatchlist(accountId: Int, movieId: Int) async throws -> TMDBStatusResponse {
        let request = try TMDBEndpoint.removeFromWatchlist(accountId: accountId, movieId: movieId).makeRequest()
        return try await service.execute(request)
    }

    // MARK: - Delete (DELETE)

    /// Delete a movie rating. Uses void response (no body returned).
    func deleteRating(id: Int) async throws {
        let request = try TMDBEndpoint.deleteRating(id: id).makeRequest()
        try await service.execute(request)
    }
}
