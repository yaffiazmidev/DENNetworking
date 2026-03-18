import SwiftUI
import DENNetworking

@main
struct ExampleApp: App {
    @State private var router = AppRouter()
    @State private var dependencies = AppDependencies()
    
    init() {
        #if DEBUG
        DENNetworkLogger.isEnabled = true
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                let viewModel = dependencies.makeNowPlayingViewModel()
                NowPlayingView(viewModel: viewModel)
                    .withAppRouter(dependencies: dependencies)
            }
            .environment(router)
        }
    }
}
