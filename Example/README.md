# Example App — TMDB Movie Browser

A full SwiftUI app demonstrating all CRUD operations with [DENNetworking](../README.md) using the [TMDB API](https://www.themoviedb.org/documentation/api).

## Getting Started

### 1. Open the project

```bash
open Example/Example.xcodeproj
```

### 2. Get a TMDB API Key

1. Create an account at [themoviedb.org](https://www.themoviedb.org/signup)
2. Go to **Settings > API** and request an API key
3. Update the API key in `TMDB/TMDBService.swift`

### 3. Run

Select a simulator and press `Cmd + R`.

## CRUD Operations

This app demonstrates every HTTP method with DENNetworking:

| Operation | Method | Endpoint | UI |
|-----------|--------|----------|----|
| **Read** popular movies | GET | `/movie/popular` | Movie list with pagination |
| **Read** movie detail | GET | `/movie/{id}` | Detail view |
| **Read** search | GET | `/search/movie` | Search bar |
| **Create** rating | POST | `/movie/{id}/rating` | "Rate" button |
| **Create** watchlist | POST | `/account/{id}/watchlist` | "Add to Watchlist" button |
| **Update** rating | PUT | `/movie/{id}/rating` | "Update" button |
| **Update** watchlist | PUT | `/account/{id}/watchlist` | "Remove from Watchlist" button |
| **Delete** rating | DELETE | `/movie/{id}/rating` | "Delete" button (void response) |

## Architecture

The example app demonstrates several patterns that work well with DENNetworking:

### Endpoint Enum

Centralizes all URL construction and request building in one place:

```swift
enum TMDBEndpoint {
    static func popular(page: Int) throws -> URLRequest {
        try URLRequest
            .url("https://api.themoviedb.org/3/movie/popular")
            .method(.GET)
            .queries([URLQueryItem(name: "page", value: "\(page)")])
            .build()
    }

    static func rateMovie(id: Int, rating: Double) throws -> URLRequest {
        try URLRequest
            .url("https://api.themoviedb.org/3/movie/\(id)/rating")
            .method(.POST)
            .body(RateMovieRequest(value: rating))
            .build()
    }
}
```

### Decorator Pattern

`TMDBAPIKeyDecorator` injects the API key on every request without modifying the core client:

```swift
final class TMDBAPIKeyDecorator: DENNetworkHTTPClient {
    private let decoratee: DENNetworkHTTPClient
    private let apiKey: String

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request
        // Inject api_key query parameter
        // ...
        return try await decoratee.load(mutableRequest)
    }
}
```

### Repository Pattern

Typed async methods decoupled from UI:

```swift
final class TMDBRepository {
    private let service: DENNetworkingServiceProtocol

    func fetchPopularMovies(page: Int) async throws -> TMDBResponse<Movie> {
        try await service.execute(TMDBEndpoint.popular(page: page))
    }

    func rateMovie(id: Int, rating: Double) async throws -> TMDBStatusResponse {
        try await service.execute(TMDBEndpoint.rateMovie(id: id, rating: rating))
    }

    func deleteRating(id: Int) async throws {
        try await service.execute(TMDBEndpoint.deleteRating(id: id))
    }
}
```

### ViewModel Pattern

`@MainActor @Observable` for SwiftUI state management with per-case error handling:

```swift
@MainActor @Observable
final class MovieListViewModel {
    var movies: [Movie] = []
    var errorMessage: String?
    var isLoading = false

    func loadPopularMovies() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repository.fetchPopularMovies(page: currentPage)
            movies.append(contentsOf: response.results)
        } catch let error as DENNetworkError {
            errorMessage = mapError(error)
        }
    }
}
```

### Service Factory

Composes the full client stack with swappable transport:

```swift
enum TMDBServiceFactory {
    enum Transport {
        case urlSession   // Apple built-in, zero dependencies
        case alamofire    // Alamofire-backed, more features
    }

    static func make(transport: Transport = .urlSession) -> DENNetworkingServiceProtocol {
        let httpClient: DENNetworkHTTPClient = switch transport {
        case .urlSession: DENNetworkURLSessionHTTPClient()
        case .alamofire:  AlamofireHTTPClient()
        }

        let withApiKey = TMDBAPIKeyDecorator(decoratee: httpClient, apiKey: apiKey)
        return DENNetworkService(client: withApiKey, decoder: ...)
    }
}
```

### Alamofire Integration

This example shows how to use Alamofire as the HTTP transport with DENNetworking. The key insight: **only the transport layer changes** — decorators, service, repository, views, and tests all stay the same.

#### Setup

1. In Xcode: **File > Add Package Dependencies**
2. Enter: `https://github.com/Alamofire/Alamofire.git`
3. Add to Example target

#### Switch transport

Change one line in `MovieListViewModel.swift`:

```swift
// URLSession (default, zero dependencies)
init(repository: TMDBRepository = TMDBRepository(service: TMDBServiceFactory.make(transport: .urlSession)))

// Alamofire
init(repository: TMDBRepository = TMDBRepository(service: TMDBServiceFactory.make(transport: .alamofire)))

// Alamofire + Retry (exponential backoff with jitter)
init(repository: TMDBRepository = TMDBRepository(service: TMDBServiceFactory.makeWithRetry()))
```

#### How it works

`AlamofireHTTPClient` conforms to `DENNetworkHTTPClient` — the same single-method protocol:

```swift
public final class AlamofireHTTPClient: DENNetworkHTTPClient {
    private let session: Session

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = await session.request(request)
            .validate(statusCode: 0..<600)
            .serializingData()
            .response
        // Map to (Data, HTTPURLResponse) — DENNetworkService handles the rest
    }
}
```

Because `DENNetworkHTTPClient` is a protocol, swapping URLSession for Alamofire is transparent:

```
URLSession version:                    Alamofire version:
┌──────────────────────┐               ┌──────────────────────┐
│ DENNetworkURLSession │               │ AlamofireHTTPClient  │
│     HTTPClient       │               │                      │
└──────────┬───────────┘               └──────────┬───────────┘
           │ (same protocol)                      │ (same protocol)
           ▼                                      ▼
┌──────────────────────┐               ┌──────────────────────┐
│ TMDBAPIKeyDecorator  │  ← identical  │ TMDBAPIKeyDecorator  │
│ DENNetworkService    │  ← identical  │ DENNetworkService    │
│ TMDBRepository       │  ← identical  │ TMDBRepository       │
│ ViewModels           │  ← identical  │ ViewModels           │
│ Views                │  ← identical  │ Views                │
└──────────────────────┘               └──────────────────────┘
```

#### Advanced: Alamofire with certificate pinning

```swift
let evaluators: [String: ServerTrustEvaluating] = [
    "api.themoviedb.org": PinnedCertificatesTrustEvaluator()
]
let manager = ServerTrustManager(evaluators: evaluators)
let session = Session(serverTrustManager: manager)
let client = AlamofireHTTPClient(session: session)
```

## Project Structure

```
Example/
├── Example/
│   ├── ExampleApp.swift                 — App entry point + logger setup
│   ├── ContentView.swift
│   ├── TMDB/
│   │   ├── TMDBModels.swift             — Movie, MovieDetail, CRUD request/response models
│   │   ├── TMDBEndpoint.swift           — All CRUD endpoints (GET, POST, PUT, DELETE)
│   │   ├── TMDBAPIKeyDecorator.swift    — Decorator: injects API key
│   │   ├── TMDBService.swift            — Factory: composes client stack (URLSession or Alamofire)
│   │   ├── AlamofireHTTPClient.swift    — Alamofire adapter for DENNetworkHTTPClient
│   │   └── TMDBRepository.swift         — Typed async CRUD methods
│   └── Views/
│       ├── MovieListView.swift          — List + search + pagination
│       ├── MovieListViewModel.swift     — List state management
│       ├── MovieDetailView.swift        — Detail + rate/watchlist/delete actions
│       ├── MovieDetailViewModel.swift   — Detail state management
│       └── StarRatingView.swift         — Interactive 5-star rating component
└── ExampleTests/
    ├── Helpers/
    │   ├── MockHTTPClient.swift          — HTTP client mock with request recording
    │   └── TMDBFixtures.swift            — JSON fixtures for test data
    ├── TMDBModelsTests.swift             — Model computed properties + decoding
    ├── TMDBEndpointTests.swift           — All endpoint URL/method/body validation
    ├── TMDBAPIKeyDecoratorTests.swift     — Decorator key injection tests
    ├── TMDBRepositoryTests.swift          — Full CRUD operation tests
    ├── MovieListViewModelTests.swift      — List VM state + error mapping
    └── MovieDetailViewModelTests.swift    — Detail VM CRUD + state transitions
```

## Tests

Run the example tests in Xcode:

```
Cmd + U
```

All layers are tested with mocks — no real API calls needed:

- **Endpoints** — URL construction, HTTP methods, request bodies, query parameters
- **Decorator** — API key injection, error propagation
- **Repository** — Full CRUD, error scenarios, void responses
- **ViewModels** — State management, error mapping, pagination

## Key Takeaways

This example demonstrates how DENNetworking enables:

1. **Clean separation** — Each layer has a single responsibility
2. **Testability** — Protocol-based design makes mocking trivial
3. **Composability** — Decorators add behavior without modifying existing code
4. **Swappable transport** — URLSession ↔ Alamofire by changing one line
5. **Type safety** — Typed endpoints, models, and error handling
6. **Modern Swift** — async/await, @Observable, Sendable conformance
