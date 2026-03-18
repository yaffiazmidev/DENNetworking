import Foundation

/// Network request/response logger.
///
/// Logging is controlled by `isEnabled` (default: `false`). Enable it at app launch:
/// ```swift
/// #if DEBUG
/// DENNetworkLogger.isEnabled = true
/// #endif
/// ```
///
/// - Important: Configure these properties once at app startup before any network calls.
///   The `#if DEBUG` gate should be in **your app code**, not in the library, to ensure
///   the compiler flag is evaluated in your module's build context.
public final class DENNetworkLogger: Sendable {

    /// Master switch. Default: `false` — opt-in to prevent logging in production.
    ///
    /// Enable in your app's entry point:
    /// ```swift
    /// #if DEBUG
    /// DENNetworkLogger.isEnabled = true
    /// #endif
    /// ```
    nonisolated(unsafe) public static var isEnabled: Bool = false

    /// Maximum lines for JSON response output. `nil` = no truncation.
    nonisolated(unsafe) public static var maxResponseLines: Int? = 50

    /// Maximum characters for non-JSON (raw) response output. `nil` = no truncation.
    nonisolated(unsafe) public static var maxRawResponseLength: Int? = 500

    public static func log(request: URLRequest) {
        guard isEnabled else { return }

        let baseURL = request.url?.host ?? "N/A"
        print("----------------------- 🚀 \(baseURL) ----------------------------")
        print("METHOD:  \(request.httpMethod ?? "N/A")")
        print("PATH:    \(request.url?.path ?? "N/A")")

        if let url = request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems, !queryItems.isEmpty {
            let queryDict = queryItems.reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value ?? ""
            }
            print("QUERY:\n\(prettyPrint(dictionary: queryDict))")
        }

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("HEADERS:\n\(prettyPrint(dictionary: headers))")
        }

        if let body = request.httpBody {
            if let prettyBody = prettyPrint(data: body) {
                print("BODY:\n \(prettyBody)")
            } else {
                print("\nBODY (RAW):\n\(String(data: body, encoding: .utf8) ?? "Non-UTF8 data")")
            }
        }
    }

    public static func log(responseData data: Data, response: HTTPURLResponse) {
        guard isEnabled else { return }

        let icon: String
        switch response.statusCode {
        case 200..<300: icon = "✅ SUCCESS"
        case 400..<500: icon = "⚠️ CLIENT ERROR"
        default: icon = "❌ SERVER ERROR"
        }

        print("\n------------------ \(icon) • \(response.statusCode) ------------------")
        defer { print("------------------------------------------------\n") }

        let urlString = response.url?.absoluteString ?? "N/A"

        var output = """
        URL: \(urlString)
        """

        if data.isEmpty {
            output += "\n📥 RESPONSE • [Empty]"
        } else if let prettyResponse = prettyPrint(data: data) {
            output += "\n📥 RESPONSE • \(formatBytes(data.count))\n"

            let lines = prettyResponse.split(separator: "\n", omittingEmptySubsequences: false)
            let limit = maxResponseLines ?? lines.count
            let truncated = lines.count > limit

            for line in lines.prefix(limit) {
                output += "     \(line)\n"
            }

            if truncated {
                output += "     ... (\(lines.count - limit) more lines truncated)\n"
            }
        } else {
            let rawString = String(data: data, encoding: .utf8) ?? "Non-UTF8 data"
            let truncatedRaw: String
            if let maxLength = maxRawResponseLength, rawString.count > maxLength {
                truncatedRaw = String(rawString.prefix(maxLength)) + "... (\(rawString.count - maxLength) chars truncated)"
            } else {
                truncatedRaw = rawString
            }
            output += "\n📥 RESPONSE • (RAW):\n\(truncatedRaw)"
        }

        print(output)
    }

    public static func log(error: Error) {
        guard isEnabled else { return }
        print("\(error)")
    }
}

extension DENNetworkLogger {

    static func debugPrint(_ string: String) {
        guard isEnabled else { return }
        print(string)
    }

    // MARK: - Private Helpers

    private static func prettyPrint(data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }

    private static func prettyPrint(dictionary: [String: Any]) -> String {
        return dictionary.map { key, value in "  \(key): \(value)" }.joined(separator: "\n")
    }

    private static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.2f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}
