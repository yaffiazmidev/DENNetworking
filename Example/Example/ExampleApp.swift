import SwiftUI
import DENNetworking

@main
struct ExampleApp: App {

    init() {
        #if DEBUG
        DENNetworkLogger.isEnabled = true
        DENNetworkLogger.maxResponseLines = 30
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
