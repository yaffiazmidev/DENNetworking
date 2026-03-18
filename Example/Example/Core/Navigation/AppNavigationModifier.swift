import SwiftUI

struct AppNavigationModifier: ViewModifier {
    var dependencies: AppDependencies

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .nowPlaying:
                    let vm = dependencies.makeNowPlayingViewModel()
                    NowPlayingView(viewModel: vm)
                case .movieDetail(let movieId):
                    let vm = dependencies.makeMovieDetailViewModel(movieId: movieId)
                    MovieDetailView(viewModel: vm)
                }
            }
    }
}

extension View {
    func withAppRouter(dependencies: AppDependencies) -> some View {
        self.modifier(AppNavigationModifier(dependencies: dependencies))
    }
}
