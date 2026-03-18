import XCTest
@testable import DENNetworking

final class MultipartFormDataTests: XCTestCase {

    // MARK: - Content Type

    func test_contentType_includesBoundary() {
        let sut = MultipartFormData(boundary: "test-boundary")

        XCTAssertEqual(sut.contentType, "multipart/form-data; boundary=test-boundary")
    }

    // MARK: - Text Field

    func test_encode_singleTextField() {
        var sut = MultipartFormData(boundary: "boundary123")
        sut.addField(name: "title", value: "Hello World")

        let encoded = sut.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("--boundary123\r\n"))
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"title\""))
        XCTAssertTrue(body.contains("Hello World"))
        XCTAssertTrue(body.contains("--boundary123--"))
    }

    func test_encode_multipleTextFields() {
        var sut = MultipartFormData(boundary: "boundary123")
        sut.addField(name: "name", value: "Den")
        sut.addField(name: "email", value: "den@example.com")

        let encoded = sut.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("name=\"name\""))
        XCTAssertTrue(body.contains("Den"))
        XCTAssertTrue(body.contains("name=\"email\""))
        XCTAssertTrue(body.contains("den@example.com"))
    }

    // MARK: - File Upload

    func test_encode_fileAttachment() {
        var sut = MultipartFormData(boundary: "boundary123")
        let fileData = "fake image data".data(using: .utf8)!
        sut.addFile(name: "avatar", filename: "photo.jpg", mimeType: "image/jpeg", data: fileData)

        let encoded = sut.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"avatar\"; filename=\"photo.jpg\""))
        XCTAssertTrue(body.contains("Content-Type: image/jpeg"))
        XCTAssertTrue(body.contains("fake image data"))
        XCTAssertTrue(body.contains("--boundary123--"))
    }

    // MARK: - Mixed

    func test_encode_fieldAndFile() {
        var sut = MultipartFormData(boundary: "boundary123")
        sut.addField(name: "description", value: "My photo")
        let fileData = "fake-png-data".data(using: .utf8)!
        sut.addFile(name: "image", filename: "test.png", mimeType: "image/png", data: fileData)

        let encoded = sut.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("name=\"description\""))
        XCTAssertTrue(body.contains("My photo"))
        XCTAssertTrue(body.contains("name=\"image\"; filename=\"test.png\""))
        XCTAssertTrue(body.contains("Content-Type: image/png"))
    }

    // MARK: - Empty

    func test_encode_emptyFormData() {
        let sut = MultipartFormData(boundary: "boundary123")
        let encoded = sut.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertEqual(body, "--boundary123--\r\n")
    }

    // MARK: - Binary Data Integrity

    func test_encode_preservesBinaryData() {
        var sut = MultipartFormData(boundary: "boundary123")
        let binaryData = Data((0..<256).map { UInt8($0) })
        sut.addFile(name: "file", filename: "data.bin", mimeType: "application/octet-stream", data: binaryData)

        let encoded = sut.encode()

        // Verify the binary data is contained within the encoded body
        XCTAssertTrue(encoded.count > binaryData.count)
        let range = encoded.range(of: binaryData)
        XCTAssertNotNil(range, "Binary data should be present in encoded body")
    }

    // MARK: - MIME Type Constants

    func test_mimeTypeConstants() {
        XCTAssertEqual(MultipartFormData.MIMEType.jpeg, "image/jpeg")
        XCTAssertEqual(MultipartFormData.MIMEType.png, "image/png")
        XCTAssertEqual(MultipartFormData.MIMEType.gif, "image/gif")
        XCTAssertEqual(MultipartFormData.MIMEType.pdf, "application/pdf")
        XCTAssertEqual(MultipartFormData.MIMEType.json, "application/json")
        XCTAssertEqual(MultipartFormData.MIMEType.plainText, "text/plain")
        XCTAssertEqual(MultipartFormData.MIMEType.octetStream, "application/octet-stream")
    }

    // MARK: - Builder Integration

    func test_urlRequestBuilder_multipart() throws {
        var multipart = MultipartFormData(boundary: "test-boundary")
        multipart.addField(name: "title", value: "Test")

        let request = try URLRequest
            .url("https://api.example.com/upload")
            .method(.POST)
            .multipart(multipart)
            .build()

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "multipart/form-data; boundary=test-boundary")
        XCTAssertNotNil(request.httpBody)

        let body = String(data: request.httpBody!, encoding: .utf8)!
        XCTAssertTrue(body.contains("name=\"title\""))
        XCTAssertTrue(body.contains("Test"))
    }

    // MARK: - Boundary Uniqueness

    func test_defaultBoundary_isUnique() {
        let form1 = MultipartFormData()
        let form2 = MultipartFormData()

        XCTAssertNotEqual(form1.boundary, form2.boundary)
        XCTAssertTrue(form1.boundary.hasPrefix("DENNetworking-"))
        XCTAssertTrue(form2.boundary.hasPrefix("DENNetworking-"))
    }
}
