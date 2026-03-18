import Foundation
import DENNetworking

@Observable
class MovieDetailViewModel {

    private let movieId: Int
    private let movieDetailService: MovieDetailServiceProtocol
    var isLoading: Bool = false
    var detail: MovieDetailItemViewModel? = nil
    var errorMessage: String? = nil

    init(movieId: Int, movieDetailService: MovieDetailServiceProtocol) {
        self.movieId = movieId
        self.movieDetailService = movieDetailService
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await movieDetailService.getDetail(movieId: movieId)
            detail = response.asViewModel
            isLoading = false
        } catch {
            isLoading = false
            let error = error as? DENNetworkError
            errorMessage = error?.errorDescription ?? "An unexpected error occurred."
        }
    }
}
