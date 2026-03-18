import Foundation
import DENNetworking

@Observable
class NowPlayingViewModel {

    private let nowPlayingService: NowPlayingServiceProtocol
    var isLoading: Bool = false
    var items: [NowPlayingItemViewModel] = []
    var errorMessage: String? = nil

    init(nowPlayingService: NowPlayingServiceProtocol) {
        self.nowPlayingService = nowPlayingService
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await nowPlayingService.getItems()
            items = response.asViewModels
            isLoading = false
        } catch {
            isLoading = false
            let error = error as? DENNetworkError
            errorMessage = error?.errorDescription ?? "An unexpected error occurred."
        }
    }
}
