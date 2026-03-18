import XCTest
@testable import DENNetworking

final class DENNetworkLoggerTests: XCTestCase {

    // MARK: - State Management

    private var previousIsEnabled: Bool = true
    private var previousMaxResponseLines: Int? = 50
    private var previousMaxRawResponseLength: Int? = 500

    override func setUp() {
        super.setUp()
        previousIsEnabled = DENNetworkLogger.isEnabled
        previousMaxResponseLines = DENNetworkLogger.maxResponseLines
        previousMaxRawResponseLength = DENNetworkLogger.maxRawResponseLength
        DENNetworkLogger.isEnabled = true
        DENNetworkLogger.maxResponseLines = 50
        DENNetworkLogger.maxRawResponseLength = 500
    }

    override func tearDown() {
        DENNetworkLogger.isEnabled = previousIsEnabled
        DENNetworkLogger.maxResponseLines = previousMaxResponseLines
        DENNetworkLogger.maxRawResponseLength = previousMaxRawResponseLength
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func makeURL(_ string: String = "https://example.com/api/v1/users") -> URL {
        URL(string: string)!
    }

    // MARK: - log(request:) — No Crash Tests

    func test_logRequest_getRequest_doesNotCrash() {
        var request = URLRequest(url: makeURL())
        request.httpMethod = "GET"
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_postRequestWithBody_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/login"))
        request.httpMethod = "POST"
        let body = ["username": "alice", "password": "secret"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_withHeaders_doesNotCrash() {
        var request = URLRequest(url: makeURL())
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer token123", forHTTPHeaderField: "Authorization")
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_withQueryParams_doesNotCrash() {
        let url = URL(string: "https://example.com/api/v1/search?q=swift&page=1&limit=20")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_putRequestWithBody_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/users/42"))
        request.httpMethod = "PUT"
        let body = ["name": "Bob", "email": "bob@example.com"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_deleteRequest_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/users/42"))
        request.httpMethod = "DELETE"
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_nilURL_doesNotCrash() {
        // URLRequest requires a URL at initialisation, so the closest to a nil-URL
        // scenario is a request whose URL evaluates to an empty path/host.
        let request = URLRequest(url: URL(string: "https://")!)
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_emptyHeaders_doesNotCrash() {
        var request = URLRequest(url: makeURL())
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [:]
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_nonJSONBody_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/upload"))
        request.httpMethod = "POST"
        request.httpBody = "plain text body".data(using: .utf8)
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_nonUTF8Body_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/data"))
        request.httpMethod = "POST"
        // Latin-1 bytes that are not valid UTF-8
        request.httpBody = Data([0xFF, 0xFE, 0xFD])
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_largeBody_doesNotCrash() {
        var request = URLRequest(url: makeURL("https://example.com/api/v1/bulk"))
        request.httpMethod = "POST"
        let largeArray = Array(repeating: ["id": 1, "value": "data"], count: 500)
        request.httpBody = try? JSONSerialization.data(withJSONObject: largeArray)
        DENNetworkLogger.log(request: request)
    }

    func test_logRequest_noQueryItems_doesNotCrash() {
        // URL with a '?' but no items — edge case for URLComponents parsing
        let url = URL(string: "https://example.com/api/v1/items?")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        DENNetworkLogger.log(request: request)
    }

    // MARK: - log(request:) — isEnabled = false

    func test_logRequest_whenDisabled_doesNotCrash() {
        DENNetworkLogger.isEnabled = false
        var request = URLRequest(url: makeURL())
        request.httpMethod = "GET"
        DENNetworkLogger.log(request: request)
        // No assertion needed beyond verifying no crash and no side effects.
    }

    // MARK: - log(responseData:response:) — No Crash Tests

    func test_logResponse_emptyData_status200_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        DENNetworkLogger.log(responseData: Data(), response: response)
    }

    func test_logResponse_validJSON_status200_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let json = ["id": 1, "name": "Alice"] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_validJSONArray_status200_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let json = [["id": 1], ["id": 2], ["id": 3]] as [[String: Any]]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_nonJSONData_status200_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let data = "plain text response".data(using: .utf8)!
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_status400_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 400)
        let json = ["error": "Bad Request"] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_status401_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 401)
        DENNetworkLogger.log(responseData: Data(), response: response)
    }

    func test_logResponse_status404_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 404)
        let json = ["error": "Not Found"] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_status500_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 500)
        let json = ["error": "Internal Server Error"] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_status503_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 503)
        DENNetworkLogger.log(responseData: Data(), response: response)
    }

    func test_logResponse_nonUTF8Data_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let data = Data([0xC3, 0x28, 0xFF, 0xFE])
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_largeJSONData_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let largeArray = (0..<1000).map { ["index": $0, "value": "item \($0)"] }
        let data = try! JSONSerialization.data(withJSONObject: largeArray)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_largeRawData_doesNotCrash() {
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let longString = String(repeating: "x", count: 10_000)
        let data = longString.data(using: .utf8)!
        DENNetworkLogger.log(responseData: data, response: response)
    }

    // MARK: - log(responseData:response:) — isEnabled = false

    func test_logResponse_whenDisabled_doesNotCrash() {
        DENNetworkLogger.isEnabled = false
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let data = try! JSONSerialization.data(withJSONObject: ["key": "value"])
        DENNetworkLogger.log(responseData: data, response: response)
    }

    // MARK: - log(error:)

    func test_logError_doesNotCrash() {
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
        DENNetworkLogger.log(error: error)
    }

    func test_logError_whenDisabled_doesNotCrash() {
        DENNetworkLogger.isEnabled = false
        let error = NSError(domain: "TestDomain", code: 0, userInfo: nil)
        DENNetworkLogger.log(error: error)
    }

    // MARK: - debugPrint — isEnabled flag

    func test_debugPrint_whenEnabled_doesNotCrash() {
        DENNetworkLogger.isEnabled = true
        DENNetworkLogger.debugPrint("test message while enabled")
    }

    func test_debugPrint_whenDisabled_doesNotCrash() {
        DENNetworkLogger.isEnabled = false
        DENNetworkLogger.debugPrint("test message while disabled")
    }

    func test_debugPrint_emptyString_doesNotCrash() {
        DENNetworkLogger.debugPrint("")
    }

    func test_debugPrint_multilineString_doesNotCrash() {
        DENNetworkLogger.debugPrint("line one\nline two\nline three")
    }

    func test_debugPrint_unicodeString_doesNotCrash() {
        DENNetworkLogger.debugPrint("Hello World! \u{1F680} \u{2705} \u{26A0}\u{FE0F}")
    }

    // MARK: - formatBytes (indirect via response logging)

    func test_formatBytes_bytesRange_doesNotCrash() {
        // Triggers the "< 1024 B" branch of formatBytes
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let smallJSON = ["a": 1] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: smallJSON)
        XCTAssertLessThan(data.count, 1024)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_formatBytes_kilobytesRange_doesNotCrash() {
        // Triggers the "< 1 MB (KB)" branch of formatBytes
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let mediumArray = (0..<100).map { ["index": $0, "data": String(repeating: "a", count: 10)] }
        let data = try! JSONSerialization.data(withJSONObject: mediumArray)
        XCTAssertGreaterThanOrEqual(data.count, 1024)
        XCTAssertLessThan(data.count, 1024 * 1024)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_formatBytes_megabytesRange_doesNotCrash() {
        // Triggers the ">= 1 MB" branch of formatBytes
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let largeString = String(repeating: "A", count: 1024 * 1024 + 1)
        let data = largeString.data(using: .utf8)!
        XCTAssertGreaterThanOrEqual(data.count, 1024 * 1024)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    // MARK: - Truncation Configuration

    func test_logResponse_maxResponseLinesNil_doesNotCrash() {
        DENNetworkLogger.maxResponseLines = nil
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let json = (0..<200).map { ["index": $0] }
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_maxResponseLinesZero_doesNotCrash() {
        DENNetworkLogger.maxResponseLines = 0
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let json = ["key": "value"] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: json)
        DENNetworkLogger.log(responseData: data, response: response)
    }

    func test_logResponse_maxRawResponseLengthNil_doesNotCrash() {
        DENNetworkLogger.maxRawResponseLength = nil
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let rawData = String(repeating: "z", count: 5000).data(using: .utf8)!
        DENNetworkLogger.log(responseData: rawData, response: response)
    }

    func test_logResponse_maxRawResponseLengthZero_doesNotCrash() {
        DENNetworkLogger.maxRawResponseLength = 0
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let rawData = "some raw content".data(using: .utf8)!
        DENNetworkLogger.log(responseData: rawData, response: response)
    }

    // MARK: - isEnabled Toggle

    func test_isEnabled_toggleDoesNotAffectPublicAPI() {
        // Verify toggling repeatedly does not leave the logger in a broken state.
        let response = makeResponse(url: makeURL(), statusCode: 200)
        let data = try! JSONSerialization.data(withJSONObject: ["toggle": true])
        var request = URLRequest(url: makeURL())
        request.httpMethod = "GET"

        for _ in 0..<5 {
            DENNetworkLogger.isEnabled = true
            DENNetworkLogger.log(request: request)
            DENNetworkLogger.log(responseData: data, response: response)
            DENNetworkLogger.debugPrint("enabled pass")

            DENNetworkLogger.isEnabled = false
            DENNetworkLogger.log(request: request)
            DENNetworkLogger.log(responseData: data, response: response)
            DENNetworkLogger.debugPrint("disabled pass")
        }
    }
}
