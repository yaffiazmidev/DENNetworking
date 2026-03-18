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
///     .body(userPayload)
///     .build()
/// ```
public extension URLRequest {

    struct Builder: Sendable {

        public enum HTTPMethod: String, Sendable {
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
        private var timeoutInterval: TimeInterval?

        private init() {}

        /// Start builder from a full `URL` object.
        static func url(_ url: URL) -> Builder {
            var builder = Builder()
            builder.components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
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

        /// Appends a path segment to the existing path, automatically handling slashes.
        public func path(_ path: String) -> Builder {
            var builder = self
            let current = builder.components.path
            let needsSlash = !current.hasSuffix("/") && !path.hasPrefix("/")
            let doubleSlash = current.hasSuffix("/") && path.hasPrefix("/")

            if doubleSlash {
                builder.components.path += String(path.dropFirst())
            } else if needsSlash && !current.isEmpty {
                builder.components.path += "/" + path
            } else {
                builder.components.path += path
            }
            return builder
        }

        public func headers(key: String, value: String) -> Builder {
            var builder = self
            builder.headers[key] = value
            return builder
        }

        /// Sets multiple headers at once.
        ///
        /// ```swift
        /// .headers([
        ///     "Content-Type": "application/json",
        ///     "Accept": "application/json"
        /// ])
        /// ```
        public func headers(_ headers: [String: String]) -> Builder {
            var builder = self
            builder.headers.merge(headers) { _, new in new }
            return builder
        }

        /// Sets the request timeout interval in seconds.
        public func timeout(_ interval: TimeInterval) -> Builder {
            var builder = self
            builder.timeoutInterval = interval
            return builder
        }

        /// JSON-encodes an `Encodable` value as the request body.
        ///
        /// Automatically sets `Content-Type: application/json` if not already set.
        ///
        /// - Parameter encoder: Custom `JSONEncoder` for date/key strategies. Default: `JSONEncoder()`.
        /// - Throws: Encoding errors (not silenced).
        public func body(_ value: Encodable, encoder: JSONEncoder = JSONEncoder()) throws -> Builder {
            var builder = self
            builder.body = try encoder.encode(value)
            if builder.headers["Content-Type"] == nil {
                builder.headers["Content-Type"] = "application/json"
            }
            return builder
        }

        /// Sets pre-encoded `Data` as the request body (for protobuf, images, form-data, etc).
        public func bodyRaw(_ data: Data) -> Builder {
            var builder = self
            builder.body = data
            return builder
        }

        /// Sets a multipart form data body and the appropriate `Content-Type` header.
        ///
        /// ```swift
        /// var multipart = MultipartFormData()
        /// multipart.addField(name: "title", value: "My Photo")
        /// multipart.addFile(name: "image", filename: "photo.jpg",
        ///                   mimeType: MultipartFormData.MIMEType.jpeg, data: imageData)
        ///
        /// let request = try URLRequest
        ///     .url("https://api.example.com/upload")
        ///     .method(.POST)
        ///     .multipart(multipart)
        ///     .build()
        /// ```
        public func multipart(_ formData: MultipartFormData) -> Builder {
            var builder = self
            builder.body = formData.encode()
            builder.headers["Content-Type"] = formData.contentType
            return builder
        }

        public func queries(_ queries: [URLQueryItem]) -> Builder {
            var builder = self
            builder.components.queryItems = queries
            return builder
        }

        /// Converts an `Encodable` value to query parameters via JSON serialization.
        ///
        /// - Throws: `DENNetworkError.urlGeneration` if the value cannot be encoded to a dictionary.
        public func queriesEncodable(_ queries: Encodable?) throws -> Builder {
            var builder = self

            guard let queries else {
                builder.components.queryItems = nil
                return builder
            }

            let queryParameters = try queries.toQueryDictionary()
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
            if let timeoutInterval {
                request.timeoutInterval = timeoutInterval
            }
            return request
        }
    }

    /// Start builder from a relative path. Base URL prepended by `AuthenticatedHTTPClientDecorator`.
    static func path(_ path: String) -> Builder {
        return Builder.path(path)
    }

    /// Start builder from a full URL string.
    static func url(_ urlString: String) -> Builder {
        Builder.url(urlString)
    }

    /// Start builder from a `URL` object.
    static func url(_ url: URL) -> Builder {
        Builder.url(url)
    }
}

private extension Encodable {
    func toQueryDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = jsonObject as? [String: Any] else {
            throw DENNetworkError.urlGeneration
        }
        return dictionary
    }
}
