import Foundation

@Observable
class AppDependencies {

    func makeNowPlayingViewModel() -> NowPlayingViewModel {
        let networkService = DIContainer.shared.apiNetworkService
        let nowPlayingService = NowPlayingService(networkService: networkService)
        return NowPlayingViewModel(nowPlayingService: nowPlayingService)
    }

    func makeMovieDetailViewModel(movieId: Int) -> MovieDetailViewModel {
        let networkService = DIContainer.shared.apiNetworkService
        let movieDetailService = MovieDetailService(networkService: networkService)
        return MovieDetailViewModel(movieId: movieId, movieDetailService: movieDetailService)
    }
}
