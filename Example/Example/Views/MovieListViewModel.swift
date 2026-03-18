import Foundation
import DENNetworking

@MainActor
@Observable
final class MovieListViewModel {

    var movies: [Movie] = []
    var searchResults: [Movie] = []
    var errorMessage: String?
    var isLoading = false
    var searchText = ""

    private let repository: TMDBRepository
    private var currentPage = 1
    private var totalPages = 1

    var displayedMovies: [Movie] {
        searchText.isEmpty ? movies : searchResults
    }

    var hasMorePages: Bool {
        currentPage < totalPages
    }

    /// Change `.urlSession` to `.alamofire` to switch transport layer.
    /// Everything else (decorator, service, repository, views) stays unchanged.
    init(repository: TMDBRepository = TMDBRepository(service: TMDBServiceFactory.make(transport: .urlSession))) {
        self.repository = repository
    }

    func loadPopularMovies() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await repository.fetchPopularMovies(page: 1)
            movies = response.results
            currentPage = response.page
            totalPages = response.totalPages
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        isLoading = true

        do {
            let response = try await repository.fetchPopularMovies(page: currentPage + 1)
            movies.append(contentsOf: response.results)
            currentPage = response.page
            totalPages = response.totalPages
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await repository.searchMovies(query: query)
            searchResults = response.results
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func mapError(_ error: DENNetworkError) -> String {
        switch error {
        case .notConnected:
            return "No internet connection."
        case .timeout:
            return "Request timed out. Try again."
        case .unauthorized:
            return "Invalid API key."
        case .tooManyRequests:
            return "Too many requests. Wait a moment."
        case .serverError:
            return "TMDB server error. Try again later."
        case .cancelled:
            return ""
        default:
            return error.localizedDescription
        }
    }
}
