# DENNetworking

Lightweight, protocol-based networking layer for iOS built on Swift Concurrency. Zero external dependencies — pure `Foundation`.

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
  - [Basic GET Request](#1-basic-get-request)
  - [POST with JSON Body](#2-post-with-json-body)
  - [Relative Path (with Base URL Decorator)](#3-relative-path-with-base-url-decorator)
- [Configuration](#configuration)
- [Logger](#logger)
- [Error Handling](#error-handling)
- [Decorator Pattern](#decorator-pattern)
- [Custom Response Decoder](#custom-response-decoder)
- [Module Structure](#module-structure)
- [License](#license)

## Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS | 13.0+ |
| Swift | 5.5+ |
| Xcode | 14.0+ |

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
│  │  URLSession ─► TokenRefresh ─► Auth ─► Retry  │  │  Decorators (compose freely)
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

## Quick Start

### 1. Basic GET Request

```swift
import DENNetworking

// 1. Create client & service
let client = DENNetworkURLSessionHTTPClient()
let service = DENNetworkService(client: client)

// 2. Build request
let request = try URLRequest
    .url("https://api.example.com/v1/users")
    .method(.GET)
    .build()

// 3. Execute & decode
let users: [User] = try await service.execute(request)
```

### 2. POST with JSON Body

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let body = CreateUserRequest(name: "Den", email: "den@example.com")

let request = try URLRequest
    .url("https://api.example.com/v1/users")
    .method(.POST)
    .headers(key: "Content-Type", value: "application/json")
    .body(data: body)
    .build()

let user: User = try await service.execute(request)
```

### 3. Relative Path (with Base URL Decorator)

When building requests with `URLRequest.path`, you need a base-URL decorator to prepend the host and optionally inject common headers or query parameters. This decorator is external and not included in this package.

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
            .headers(key: "Content-Type", value: "application/json")
            .body(data: body)
            .build()
    }
}

let http = DENNetworkURLSessionHTTPClient()
let authed = MyAuthenticatedHTTPClientDecorator(
    decoratee: http,
    baseURL: URL(string: "https://api.example.com")!,
    headers: ["Authorization": "Bearer \(token)"],
    queryParameters: ["api_key": "..."]
)
let service = DENNetworkService(client: authed)

let users: [User] = try await service.execute(UserEndpoint.getAll(PaginationRequest(page: 1, limit: 20)))
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
    .body(data: payload, encoder: encoder)
    .build()
```

### Raw Data Body (Protobuf, Image, Form-Data)

```swift
let imageData: Data = ...
let request = try URLRequest
    .url("https://api.example.com/v1/upload")
    .method(.POST)
    .headers(key: "Content-Type", value: "image/jpeg")
    .bodyRaw(imageData)
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

All logging is gated behind `#if DEBUG` — zero output in release builds.

```swift
// Toggle logging on/off
DENNetworkLogger.isEnabled = true

// Show full response (no truncation)
DENNetworkLogger.maxResponseLines = nil
DENNetworkLogger.maxRawResponseLength = nil

// Custom limits
DENNetworkLogger.maxResponseLines = 100
DENNetworkLogger.maxRawResponseLength = 2000

// Disable logging entirely
DENNetworkLogger.isEnabled = false
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
| 429 | `.tooManyRequests` |
| Other 4xx | `.error(statusCode:data:)` |
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

### Retry Logic

Use `isRetryable` to determine if a failed request should be retried:

```swift
if let networkError = error as? DENNetworkError, networkError.isRetryable {
    // safe to retry: timeout, serverError, generic, etc.
}
```

### Status Code Checking

```swift
if let networkError = error as? DENNetworkError {
    networkError.hasStatusCode(409)  // check specific code
    networkError.isNotFoundError     // shorthand for 404
}
```

## Decorator Pattern

The protocol-based design supports wrapping clients with decorators for cross-cutting concerns. Each decorator conforms to `DENNetworkHTTPClient` and wraps another.

### Composition Example (external decorator)

```swift
let urlSession = DENNetworkURLSessionHTTPClient()

let authenticated = MyAuthenticatedHTTPClientDecorator(
    decoratee: urlSession,
    baseURL: URL(string: "https://api.example.com")!,
    headers: ["Authorization": "Bearer \(token)"],
    queryParameters: ["api_key": "..."]
)

let service = DENNetworkService(client: authenticated)
```

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

### Custom Decorator: Token Refresh

```swift
public final class TokenRefreshDecorator: DENNetworkHTTPClient {
    private let decoratee: DENNetworkHTTPClient
    private let tokenStore: TokenStore
    private let refresher: TokenRefresher

    public func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var authedRequest = attachToken(to: request)
        let (data, response) = try await decoratee.load(authedRequest)

        guard response.statusCode == 401 else { return (data, response) }

        // Refresh and retry once
        try await refresher.refresh()
        authedRequest = attachToken(to: request)
        return try await decoratee.load(authedRequest)
    }
}
```

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

## Module Structure

```
Sources/
├── DENNetworkHTTPClient.swift            — Transport protocol
├── DENNetworkURLSessionHTTPClient.swift   — URLSession implementation
├── DENNetworkService.swift                — Status code mapping + decoding
├── DENNetworkError.swift                  — Typed error enum
└── Helper/
    ├── DENNetworkLogger.swift             — Debug-only request/response logger
    └── URLRequest+Builder.swift           — Fluent request builder
```

## License

Licensed under the MIT License. See the LICENSE file for details.
