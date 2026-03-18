# DENNetworking

Lightweight, protocol-based networking layer for Apple platforms built on Swift Concurrency. Zero external dependencies — pure `Foundation`. Swift 6 ready.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Architecture](#architecture)
- [Quick Start — Full CRUD](#quick-start--full-crud)
- [Builder Convenience](#builder-convenience)
- [Configuration](#configuration)
- [Logger](#logger)
- [Error Handling](#error-handling)
- [Decorator Pattern](#decorator-pattern)
- [Built-in Decorators](#built-in-decorators)
- [Multipart Form Data](#multipart-form-data)
- [Custom Response Decoder](#custom-response-decoder)
- [Swift 6 & Default Actor Isolation](#swift-6--default-actor-isolation)
- [Example App](#example-app)
- [Module Structure](#module-structure)
- [License](#license)

## Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS | 13.0+ |
| macOS | 10.15+ |
| tvOS | 13.0+ |
| watchOS | 6.0+ |
| Swift | 5.10+ |
| Xcode | 15.0+ |

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yaffiazmidev/DENNetworking.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### Manual

Copy the `Sources/` directory into your project.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  URLRequest.Builder                  │  Build requests
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              DENNetworkHTTPClient                    │  Protocol (transport layer)
│  ┌───────────────────────────────────────────────┐  │
│  │  URLSession ─► Auth ─► Retry                  │  │  Decorators (compose freely)
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              DENNetworkService                       │  Status code mapping + decoding
│              ResponseDecoder                         │  JSON / Raw / Custom
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
                 Decodable Model
```

The core is `DENNetworkHTTPClient` — a single-method protocol:

```swift
public protocol DENNetworkHTTPClient: Sendable {
    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

Any class conforming to this protocol can be used as the HTTP transport. Decorators wrap one another to add behavior (auth, retry, token refresh) without modifying existing code.

## Quick Start — Full CRUD

### 1. Setup

```swift
import DENNetworking

let client = DENNetworkURLSessionHTTPClient()
let service = DENNetworkService(client: client)
```

### 2. Create (POST)

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let request = try URLRequest
    .url("https://api.example.com/v1/users")
    .method(.POST)
    .body(CreateUserRequest(name: "Den", email: "den@example.com"))
    .build()

let user: User = try await service.execute(request)
```

> `.body()` automatically sets `Content-Type: application/json`.

### 3. Read (GET)

```swift
let request = try URLRequest
    .url("https://api.example.com/v1/users")
    .method(.GET)
    .queries([URLQueryItem(name: "page", value: "1")])
    .build()

let users: [User] = try await service.execute(request)
```

### 4. Update (PUT)

```swift
let request = try URLRequest
    .url("https://api.example.com/v1/users/123")
    .method(.PUT)
    .body(UpdateUserRequest(name: "Den Azmi"))
    .build()

let updated: User = try await service.execute(request)
```

### 5. Delete (DELETE)

```swift
let request = try URLRequest
    .url("https://api.example.com/v1/users/123")
    .method(.DELETE)
    .build()

// Void response — validates status code only, no decoding
try await service.execute(request)
```

### 6. Relative Path (with Authenticated Decorator)

Use `URLRequest.path()` with `AuthenticatedHTTPClientDecorator` for relative URLs:

```swift
enum UserEndpoint {
    static func getAll(_ params: PaginationRequest) throws -> URLRequest {
        try URLRequest
            .path("v1/users")
            .queriesEncodable(params)
            .build()
    }

    static func create(_ body: CreateUserRequest) throws -> URLRequest {
        try URLRequest
            .path("v1/users")
            .method(.POST)
            .body(body)
            .build()
    }
}

let http = DENNetworkURLSessionHTTPClient()
let auth = AuthenticatedHTTPClientDecorator(
    decoratee: http,
    baseURL: URL(string: "https://api.example.com")!,
    tokenProvider: myTokenProvider,
    commonHeaders: ["Accept": "application/json"]
)
let service = DENNetworkService(client: auth)

let users: [User] = try await service.execute(
    UserEndpoint.getAll(PaginationRequest(page: 1, limit: 20))
)
```

## Builder Convenience

Skip `.build()` by passing the builder directly to `execute()`:

```swift
// With .build()
let request = try URLRequest.url("https://api.example.com/users").method(.GET).build()
let users: [User] = try await service.execute(request)

// Without .build() — pass builder directly
let users: [User] = try await service.execute(
    .url("https://api.example.com/users").method(.GET)
)
```

### Builder API Reference

```swift
let request = try URLRequest
    .url("https://api.example.com/v1/users")   // or .path("v1/users") or .url(someURL)
    .method(.POST)                              // GET, POST, PUT, PATCH, DELETE
    .headers(key: "X-Custom", value: "value")   // single header
    .headers(["Accept": "application/json",     // bulk headers
              "X-Platform": "iOS"])
    .body(encodablePayload)                     // auto Content-Type: application/json
    .body(payload, encoder: customEncoder)       // custom JSONEncoder
    .bodyRaw(rawData)                           // raw Data body
    .multipart(multipartFormData)               // multipart/form-data
    .queries([URLQueryItem(name: "page", value: "1")])
    .queriesEncodable(encodableParams)          // Encodable → query params
    .timeout(30.0)                              // request timeout in seconds
    .build()
```

## Configuration

### Custom JSON Decoder

For APIs that use `snake_case` keys or ISO8601 dates:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let service = DENNetworkService(
    client: client,
    decoder: JSONResponseDecoder(decoder: decoder)
)
```

### Custom JSON Encoder (Request Body)

```swift
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase

let request = try URLRequest
    .url("https://api.example.com/v1/users")
    .method(.POST)
    .body(payload, encoder: encoder)
    .build()
```

### Raw Data Response

Use `RawDataResponseDecoder` when you need raw `Data` instead of JSON:

```swift
let service = DENNetworkService(
    client: client,
    decoder: RawDataResponseDecoder()
)
let data: Data = try await service.execute(request)
```

## Logger

Logging is **opt-in** — disabled by default (`isEnabled = false`) to ensure zero output in production. Enable it in your app's entry point with a `#if DEBUG` gate:

```swift
// In your App init or AppDelegate
#if DEBUG
DENNetworkLogger.isEnabled = true
#endif
```

> **Why opt-in?** The `#if DEBUG` check must be in **your app module** (not in the library) to guarantee the compiler flag is evaluated in your build context. This ensures logging is truly disabled in release builds regardless of how the library is compiled.

### Configuration

```swift
#if DEBUG
DENNetworkLogger.isEnabled = true

// Show full response (no truncation)
DENNetworkLogger.maxResponseLines = nil
DENNetworkLogger.maxRawResponseLength = nil

// Custom limits
DENNetworkLogger.maxResponseLines = 100
DENNetworkLogger.maxRawResponseLength = 2000
#endif
```

## Error Handling

All errors are typed as `DENNetworkError`, which conforms to `Error`, `Equatable`, `Sendable`, and `LocalizedError`.

### Status Code Mapping

| HTTP Status | Error Case |
|-------------|-----------|
| 200-299 | Success (decoded) |
| 400 | `.badRequest(message:)` |
| 401 | `.unauthorized` |
| 403 | `.forbidden` |
| 404 | `.notFound` |
| 408 | `.timeout` |
| 429 | `.tooManyRequests` |
| Other 4xx | `.httpError(statusCode:data:)` |
| 500-599 | `.serverError(statusCode:)` |

### Transport Errors

| Condition | Error Case |
|-----------|-----------|
| No internet | `.notConnected` |
| Request timed out | `.timeout` |
| Task cancelled | `.cancelled` |
| Connection lost | `.notConnected` |
| Decode failure | `.decodingError(message:)` |

### Handling Errors

```swift
do {
    let users: [User] = try await service.execute(request)
} catch let error as DENNetworkError {
    switch error {
    case .unauthorized:
        // redirect to login
    case .notConnected, .timeout:
        // show offline UI
    case .decodingError(let message):
        // log decoding issue
    default:
        // show error.localizedDescription to user
    }
}
```

### Error Utilities

```swift
if let error = error as? DENNetworkError {
    error.statusCode          // Int? — the HTTP status code
    error.isRetryable         // safe to retry: timeout, serverError, etc.
    error.isClientError       // 4xx error
    error.isServerError       // 5xx error
    error.isNotFoundError     // 404
    error.hasStatusCode(409)  // check specific code
}
```

## Decorator Pattern

The protocol-based design supports wrapping clients with decorators for cross-cutting concerns. Each decorator conforms to `DENNetworkHTTPClient` and wraps another.

### Custom Decorator: Alamofire

```swift
import Alamofire

public final class AlamofireHTTPClient: DENNetworkHTTPClient, @unchecked Sendable {
    private let session: Session

    public init(session: Session = .default) {
        self.session = session
    }

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = await session.request(request)
            .validate(statusCode: 0..<600)
            .serializingData()
            .response

        guard let httpResponse = response.response else {
            throw DENNetworkError.invalidResponseWith(data: response.data ?? Data())
        }

        switch response.result {
        case .success(let data):
            return (data, httpResponse)
        case .failure(let error):
            throw DENNetworkError.generic(error.localizedDescription)
        }
    }
}

// Swap — nothing else changes
let service = DENNetworkService(client: AlamofireHTTPClient())
```

## Built-in Decorators

DENNetworking ships with two production-ready decorators. Compose them freely with each other and your own custom decorators.

### Retry Decorator

Automatically retries failed requests with configurable backoff strategies. Only retries errors where `isRetryable` is `true` (timeout, server errors, etc.). Non-retryable errors (unauthorized, not found, cancelled) are thrown immediately.

```swift
let client = DENNetworkURLSessionHTTPClient()
let retry = RetryHTTPClientDecorator(
    decoratee: client,
    maxRetries: 3,
    baseDelay: 1.0,
    strategy: .exponential(multiplier: 2.0)  // 1s → 2s → 4s
)
let service = DENNetworkService(client: retry)
```

**Backoff strategies:**

| Strategy | Behavior |
|----------|----------|
| `.constant` | Same delay every retry |
| `.exponential(multiplier:)` | Delay multiplies each attempt (default) |
| `.exponentialWithJitter(multiplier:maxJitter:)` | Exponential + random jitter to prevent thundering herd |

**Configuration:**

```swift
// Conservative retry for critical operations
let retry = RetryHTTPClientDecorator(
    decoratee: client,
    maxRetries: 5,
    baseDelay: 2.0,
    maxDelay: 60.0,
    strategy: .exponentialWithJitter(multiplier: 2.0, maxJitter: 1.0)
)
```

### Authenticated Decorator

Injects base URL, auth tokens, common headers, and query parameters. Optionally refreshes tokens on 401 responses.

```swift
let client = DENNetworkURLSessionHTTPClient()
let auth = AuthenticatedHTTPClientDecorator(
    decoratee: client,
    baseURL: URL(string: "https://api.example.com")!,
    tokenProvider: myTokenProvider,
    commonHeaders: ["Accept": "application/json"],
    commonQueryParameters: ["api_version": "2"]
)
let service = DENNetworkService(client: auth)
```

**Token Provider:** Implement the `TokenProvider` protocol to integrate with your auth system:

```swift
final class MyTokenProvider: TokenProvider {
    func currentToken() async throws -> String {
        return keychain.get("access_token") ?? ""
    }

    func refreshToken() async throws -> String {
        let newToken = try await authService.refresh()
        keychain.set(newToken, forKey: "access_token")
        return newToken
    }
}
```

**Composing decorators:** Stack retry and auth together:

```swift
let urlSession = DENNetworkURLSessionHTTPClient()
let auth = AuthenticatedHTTPClientDecorator(
    decoratee: urlSession,
    baseURL: URL(string: "https://api.example.com")!,
    tokenProvider: myTokenProvider
)
let retry = RetryHTTPClientDecorator(decoratee: auth, maxRetries: 3)
let service = DENNetworkService(client: retry)

// Relative paths work automatically:
let users: [User] = try await service.execute(
    .path("v1/users").method(.GET)
)
```

## Multipart Form Data

Upload files and form fields using `MultipartFormData`:

```swift
var multipart = MultipartFormData()
multipart.addField(name: "title", value: "My Photo")
multipart.addFile(
    name: "image",
    filename: "photo.jpg",
    mimeType: MultipartFormData.MIMEType.jpeg,
    data: imageData
)

let request = try URLRequest
    .url("https://api.example.com/v1/upload")
    .method(.POST)
    .multipart(multipart)
    .build()

try await service.execute(request)
```

**Multiple files:**

```swift
var multipart = MultipartFormData()
multipart.addField(name: "album", value: "Vacation")
multipart.addFile(name: "photos[]", filename: "beach.jpg",
                  mimeType: MultipartFormData.MIMEType.jpeg, data: beachData)
multipart.addFile(name: "photos[]", filename: "sunset.png",
                  mimeType: MultipartFormData.MIMEType.png, data: sunsetData)
multipart.addFile(name: "document", filename: "itinerary.pdf",
                  mimeType: MultipartFormData.MIMEType.pdf, data: pdfData)
```

**Common MIME types** available via `MultipartFormData.MIMEType`:

| Constant | Value |
|----------|-------|
| `.jpeg` | `image/jpeg` |
| `.png` | `image/png` |
| `.gif` | `image/gif` |
| `.pdf` | `application/pdf` |
| `.json` | `application/json` |
| `.plainText` | `text/plain` |
| `.octetStream` | `application/octet-stream` |

## Custom Response Decoder

Implement `ResponseDecoder` for non-JSON formats:

```swift
// XML Decoder
public class XMLResponseDecoder: ResponseDecoder {
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        // your XML decoding logic
    }
}

let service = DENNetworkService(client: client, decoder: XMLResponseDecoder())
```

## Swift 6 & Default Actor Isolation

DENNetworking is built with **Swift 6 language mode** and full `Sendable` conformance.

### Xcode 26+ (Default `@MainActor` Isolation)

Starting from Xcode 26, new projects use `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` by default. This means **all types are implicitly `@MainActor`**, which can cause compile errors when using DENNetworking:

```
Main actor-isolated conformance of 'MyModel' to 'Decodable'
cannot satisfy conformance requirement for a 'Sendable' type parameter 'T'
```

**Option 1: Change default isolation to `nonisolated` (recommended)**

In your Xcode project **Build Settings**, set:

```
SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated
```

Then explicitly mark only UI classes with `@MainActor`:

```swift
@MainActor
final class MyViewModel: ObservableObject { ... }
```

**Option 2: Keep `MainActor` default, mark data types `nonisolated`**

If you prefer keeping the `MainActor` default, annotate your models and networking types:

```swift
nonisolated struct User: Decodable, Sendable { ... }
nonisolated final class UserRepository: Sendable { ... }
nonisolated enum UserEndpoint { ... }
```

> **Why?** `DENNetworkService.execute()` requires `T: Decodable & Sendable`. When a type's `Decodable` conformance is isolated to `@MainActor`, it cannot satisfy this requirement from a non-MainActor async context.

## Example App

The `Example/` directory contains a full SwiftUI TMDB Movie Browser demonstrating all CRUD operations with DENNetworking.

```bash
open Example/Example.xcodeproj
```

See the [Example README](Example/README.md) for architecture details, project structure, and setup instructions.

## Module Structure

```
Sources/
├── DENNetworkHTTPClient.swift            — Transport protocol
├── DENNetworkURLSessionHTTPClient.swift   — URLSession implementation
├── DENNetworkService.swift                — Status code mapping + decoding
├── DENNetworkError.swift                  — Typed error enum
├── Decorators/
│   ├── RetryHTTPClientDecorator.swift     — Automatic retry with backoff
│   └── AuthenticatedHTTPClientDecorator.swift — Auth + base URL decorator
└── Helper/
    ├── DENNetworkLogger.swift             — Opt-in request/response logger
    ├── MultipartFormData.swift            — Multipart form data builder
    └── URLRequest+Builder.swift           — Fluent request builder
```

## License

Licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
