import Foundation

/// Fluent `URLRequest` builder.
///
/// Two entry points:
/// - `URLRequest.path("data/users")` — relative path, base URL prepended by `AuthenticatedHTTPClientDecorator`
/// - `URLRequest.url("https://api.example.com/v1/users")` — absolute URL, used as-is
///
/// Example:
/// ```swift
/// // Relative (most common)
/// let request = try URLRequest
///     .path("data/top/mktcapfull")
///     .method(.GET)
///     .queriesEncodable(params)
///     .build()
///
/// // Absolute
/// let request = try URLRequest
///     .url("https://api.example.com/v1/users")
///     .method(.POST)
///     .headers(key: "Content-Type", value: "application/json")
///     .body(data: userPayload)
///     .build()
/// ```
public extension URLRequest {

    struct Builder {

        public enum HTTPMethod: String {
            case GET
            case POST
            case PUT
            case PATCH
            case DELETE
        }

        private var components = URLComponents()
        private var method: HTTPMethod = .GET
        private var headers: [String: String] = [:]
        private var body: Data?

        private init() {}

        /// Start builder from a full `URL` object.
        static func url(_ url: URL) -> Builder {
            var builder = Builder()
            builder.components.scheme = url.scheme
            builder.components.host = url.host
            builder.components.path = url.path
            return builder
        }

        /// Start builder from a full URL string (e.g. `"https://api.example.com/v1/users"`).
        static func url(_ urlString: String) -> Builder {
            guard let url = URL(string: urlString) else {
                var builder = Builder()
                builder.components.path = urlString
                return builder
            }
            return self.url(url)
        }

        /// Start builder from a relative path (e.g. `"data/top/mktcapfull"`).
        ///
        /// Base URL is expected to be prepended later via `AuthenticatedHTTPClientDecorator`.
        static func path(_ path: String) -> Builder {
            var builder = Builder()
            builder.components.path = path
            return builder
        }

        public func method(_ method: HTTPMethod) -> Builder {
            var builder = self
            builder.method = method
            return builder
        }

        /// Appends a path segment to the existing path.
        public func path(_ path: String) -> Builder {
            var builder = self
            builder.components.path += path
            return builder
        }

        public func headers(key: String, value: String) -> Builder {
            var builder = self
            builder.headers[key] = value
            return builder
        }

        /// JSON-encodes an `Encodable` value as the request body.
        ///
        /// - Parameter encoder: Custom `JSONEncoder` for date/key strategies. Default: `JSONEncoder()`.
        /// - Throws: Encoding errors (not silenced).
        public func body(data: Encodable, encoder: JSONEncoder = JSONEncoder()) throws -> Builder {
            var builder = self
            builder.body = try encoder.encode(data)
            return builder
        }

        /// Sets pre-encoded `Data` as the request body (for protobuf, images, form-data, etc).
        public func bodyRaw(_ data: Data) -> Builder {
            var builder = self
            builder.body = data
            return builder
        }

        public func queries(_ queries: [URLQueryItem]) -> Builder {
            var builder = self
            builder.components.queryItems = queries
            return builder
        }

        /// Converts an `Encodable` value to query parameters via JSON serialization.
        public func queriesEncodable(_ queries: Encodable?) -> Builder {
            var builder = self

            guard let queryParameters = queries?.toDictionary() else {
                builder.components.queryItems = nil
                return builder
            }

            let urlQueryItems = queryParameters.compactMap({ URLQueryItem(name: $0.key, value: "\($0.value)") })
            builder.components.queryItems = !urlQueryItems.isEmpty ? urlQueryItems : nil
            return builder
        }

        /// Builds the final `URLRequest`.
        /// - Throws: `DENNetworkError.urlGeneration` if the URL cannot be constructed.
        public func build() throws -> URLRequest {
            guard let url = components.url else {
                throw DENNetworkError.urlGeneration
            }

            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.allHTTPHeaderFields = headers
            request.httpBody = body
            return request
        }
    }

    /// Start builder from a relative path. Base URL prepended by `AuthenticatedHTTPClientDecorator`.
    static func path(_ path: String) -> Builder {
        return Builder.path(path)
    }

    /// Start builder from a full URL string.
    static func url(_ urlString: String) -> Builder {
        return Builder.url(urlString)
    }
}

private extension Encodable {
    func toDictionary() -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let jsonData = try JSONSerialization.jsonObject(with: data)
            return jsonData as? [String: Any]
        } catch {
            return nil
        }
    }
}
