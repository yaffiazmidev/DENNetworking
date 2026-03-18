import Foundation
import DENNetworking

@MainActor
@Observable
final class MovieDetailViewModel {

    var detail: MovieDetail?
    var errorMessage: String?
    var successMessage: String?
    var isLoading = false
    var isActioning = false

    // Rating state
    var userRating: Double = 5.0
    var isInWatchlist = false

    private let repository: TMDBRepository
    private let movieId: Int
    private let accountId = 1 // Placeholder account ID for demo

    init(movieId: Int, repository: TMDBRepository = TMDBRepository(service: TMDBServiceFactory.make())) {
        self.movieId = movieId
        self.repository = repository
    }

    // MARK: - Read (GET)

    func loadDetail() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            detail = try await repository.fetchMovieDetail(id: movieId)
        } catch let error as DENNetworkError {
            switch error {
            case .notFound:
                errorMessage = "Movie not found."
            case .notConnected:
                errorMessage = "No internet connection."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create (POST)

    func rateMovie() async {
        guard !isActioning else { return }
        isActioning = true
        clearMessages()

        do {
            let response = try await repository.rateMovie(id: movieId, rating: userRating)
            successMessage = response.statusMessage
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    func addToWatchlist() async {
        guard !isActioning else { return }
        isActioning = true
        clearMessages()

        do {
            let response = try await repository.addToWatchlist(accountId: accountId, movieId: movieId)
            successMessage = response.statusMessage
            isInWatchlist = true
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    // MARK: - Update (PUT)

    func updateRating() async {
        guard !isActioning else { return }
        isActioning = true
        clearMessages()

        do {
            let response = try await repository.updateRating(id: movieId, rating: userRating)
            successMessage = response.statusMessage
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    func removeFromWatchlist() async {
        guard !isActioning else { return }
        isActioning = true
        clearMessages()

        do {
            let response = try await repository.removeFromWatchlist(accountId: accountId, movieId: movieId)
            successMessage = response.statusMessage
            isInWatchlist = false
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    // MARK: - Delete (DELETE)

    func deleteRating() async {
        guard !isActioning else { return }
        isActioning = true
        clearMessages()

        do {
            try await repository.deleteRating(id: movieId)
            successMessage = "Rating deleted."
            userRating = 5.0
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isActioning = false
    }

    // MARK: - Private

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func mapError(_ error: DENNetworkError) -> String {
        switch error {
        case .unauthorized:
            return "Authentication required. Please log in."
        case .notFound:
            return "Movie not found."
        case .notConnected:
            return "No internet connection."
        default:
            return error.localizedDescription
        }
    }
}
