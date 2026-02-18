import Foundation

/// Debug-only network request/response logger.
///
/// All output is gated behind `#if DEBUG` and `isEnabled`. Configure in SceneDelegate:
/// ```swift
/// DENNetworkLogger.isEnabled = true
/// DENNetworkLogger.maxResponseLines = nil     // full JSON output
/// DENNetworkLogger.maxRawResponseLength = nil  // full raw output
/// ```
public final class DENNetworkLogger {

    /// Master switch. Set `false` to silence all network logging. Default: `true`.
    public static var isEnabled: Bool = true

    /// Maximum lines for JSON response output. `nil` = no truncation.
    public static var maxResponseLines: Int? = 50

    /// Maximum characters for non-JSON (raw) response output. `nil` = no truncation.
    public static var maxRawResponseLength: Int? = 500

    public static func log(request: URLRequest) {
        let baseURL = request.url?.host ?? "N/A"
        debugPrint("----------------------- \u{1F680} \(baseURL) ----------------------------")
        debugPrint("METHOD:  \(request.httpMethod ?? "N/A")")
        debugPrint("PATH:    \(request.url?.path ?? "N/A")")

        if let url = request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems, !queryItems.isEmpty {
            let queryDict = queryItems.reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value ?? ""
            }
            debugPrint("QUERY:\n\(prettyPrint(dictionary: queryDict))")
        }

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            debugPrint("HEADERS:\n\(prettyPrint(dictionary: headers))")
        }

        if let body = request.httpBody {
            if let prettyBody = prettyPrint(data: body) {
                debugPrint("BODY:\n \(prettyBody)")
            } else {
                debugPrint("\nBODY (RAW):\n\(String(data: body, encoding: .utf8) ?? "Non-UTF8 data")")
            }
        }
    }

    public static func log(responseData data: Data, response: HTTPURLResponse) {
        let icon: String
        switch response.statusCode {
        case 200..<300: icon = "\u{2705} SUCCESS"
        case 400..<500: icon = "\u{26A0}\u{FE0F} CLIENT ERROR"
        default: icon = "\u{274C} SERVER ERROR"
        }

        debugPrint("\n------------------ \(icon) \u{2022} \(response.statusCode) ------------------")
        defer { debugPrint("------------------------------------------------\n") }

        let urlString = response.url?.absoluteString ?? "N/A"

        var output = """
        URL: \(urlString)
        """

        if data.isEmpty {
            output += "\n\u{1F4E5} RESPONSE \u{2022} [Empty]"
        } else if let prettyResponse = prettyPrint(data: data) {
            output += "\n\u{1F4E5} RESPONSE \u{2022} \(formatBytes(data.count))\n"

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
            output += "\n\u{1F4E5} RESPONSE \u{2022} (RAW):\n\(truncatedRaw)"
        }

        debugPrint(output)
    }

    public static func log(error: Error) {
        debugPrint("\(error)")
    }
}

extension DENNetworkLogger {
    // MARK: - Internal

    static func debugPrint(_ string: String) {
        #if DEBUG
        guard isEnabled else { return }
        print(string)
        #endif
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
