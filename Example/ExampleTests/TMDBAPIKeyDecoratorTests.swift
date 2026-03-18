import XCTest
import DENNetworking
@testable import Example

final class TMDBAPIKeyDecoratorTests: XCTestCase {

    func test_load_appendsAPIKeyToQuery() async throws {
        let mockClient = MockHTTPClient.success()
        let sut = TMDBAPIKeyDecorator(decoratee: mockClient, apiKey: "test_key_123")

        let request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/popular?page=1")!)
        _ = try await sut.load(request)

        let loadedURL = mockClient.loadedRequests.first?.url
        XCTAssertNotNil(loadedURL)

        let components = URLComponents(url: loadedURL!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "test_key_123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "1")))
    }

    func test_load_appendsAPIKeyWhenNoExistingQuery() async throws {
        let mockClient = MockHTTPClient.success()
        let sut = TMDBAPIKeyDecorator(decoratee: mockClient, apiKey: "my_key")

        let request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/550")!)
        _ = try await sut.load(request)

        let loadedURL = mockClient.loadedRequests.first?.url
        let components = URLComponents(url: loadedURL!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []

        XCTAssertEqual(queryItems.count, 1)
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "my_key")))
    }

    func test_load_propagatesError() async {
        let mockClient = MockHTTPClient.failure(DENNetworkError.notConnected)
        let sut = TMDBAPIKeyDecorator(decoratee: mockClient, apiKey: "key")

        let request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/movie/popular")!)

        do {
            _ = try await sut.load(request)
            XCTFail("Expected error")
        } catch let error as DENNetworkError {
            XCTAssertEqual(error, .notConnected)
        }
    }
}
