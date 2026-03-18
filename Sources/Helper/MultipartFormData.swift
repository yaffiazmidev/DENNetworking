import Foundation

/// Builder for constructing `multipart/form-data` request bodies.
///
/// Supports text fields and file uploads. Generates the appropriate boundary and content type.
///
/// Usage:
/// ```swift
/// var multipart = MultipartFormData()
/// multipart.addField(name: "title", value: "My Photo")
/// multipart.addFile(
///     name: "image",
///     filename: "photo.jpg",
///     mimeType: "image/jpeg",
///     data: imageData
/// )
///
/// let request = try URLRequest
///     .url("https://api.example.com/upload")
///     .method(.POST)
///     .multipart(multipart)
///     .build()
/// ```
public struct MultipartFormData: Sendable {

    /// A single part in the multipart body.
    public enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, mimeType: String, data: Data)
    }

    /// The boundary string used to separate parts. Auto-generated.
    public let boundary: String

    /// The `Content-Type` header value including the boundary.
    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    private var parts: [Part] = []

    /// Whether this form data has no parts.
    public var isEmpty: Bool { parts.isEmpty }

    /// Creates a new multipart form data builder.
    ///
    /// - Parameter boundary: Custom boundary string (optional). Auto-generated if not provided.
    public init(boundary: String = "DENNetworking-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    /// Adds a text field.
    public mutating func addField(name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    /// Adds a file attachment.
    ///
    /// - Parameters:
    ///   - name: The form field name (e.g. `"image"`, `"file"`, `"attachment"`).
    ///   - filename: The filename to send to the server (e.g. `"photo.jpg"`).
    ///   - mimeType: MIME type of the file (e.g. `"image/jpeg"`, `"application/pdf"`).
    ///   - data: The file's raw data.
    public mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        parts.append(.file(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    /// Encodes all parts into the final `Data` body.
    public func encode() -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append("--\(boundary)\(crlf)")

            switch part {
            case .field(let name, let value):
                body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)")
                body.append(crlf)
                body.append(value)
                body.append(crlf)

            case .file(let name, let filename, let mimeType, let data):
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(crlf)")
                body.append("Content-Type: \(mimeType)\(crlf)")
                body.append(crlf)
                body.append(data)
                body.append(crlf)
            }
        }

        body.append("--\(boundary)--\(crlf)")
        return body
    }

    /// Common MIME types for convenience.
    public enum MIMEType {
        public static let jpeg = "image/jpeg"
        public static let png = "image/png"
        public static let gif = "image/gif"
        public static let pdf = "application/pdf"
        public static let json = "application/json"
        public static let plainText = "text/plain"
        public static let octetStream = "application/octet-stream"
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
