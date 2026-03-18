import Foundation
import SwiftUI

enum AppRoute: Hashable {
    case nowPlaying
    case movieDetail(movieId: Int)
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
