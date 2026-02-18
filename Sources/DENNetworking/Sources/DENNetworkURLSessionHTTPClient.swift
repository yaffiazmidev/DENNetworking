import Foundation

/// Default `DENNetworkHTTPClient` implementation using `URLSession`.
///
/// Marked `@unchecked Sendable` because `URLSession` is thread-safe by Apple's documentation
/// but not formally marked `Sendable` in the SDK.
///
/// To swap with Alamofire or another library, create a new class conforming to `DENNetworkHTTPClient` instead.
public final class DENNetworkURLSessionHTTPClient: DENNetworkHTTPClient, @unchecked Sendable {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    @discardableResult
    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        DENNetworkLogger.log(request: request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DENNetworkError.invalidResponseWith(data: data)
            }

            DENNetworkLogger.log(responseData: data, response: httpResponse)

            return (data, httpResponse)
        } catch let error as DENNetworkError {
            throw error
        } catch {
            throw resolve(error: error)
        }
    }

    private func resolve(error: Error) -> DENNetworkError {
        let code = URLError.Code(rawValue: (error as NSError).code)
        switch code {
        case .notConnectedToInternet: return .notConnected
        case .cancelled: return .cancelled
        case .timedOut: return .timeout
        case .networkConnectionLost: return .notConnected
        default: return .generic(error.localizedDescription)
        }
    }
}
