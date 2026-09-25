import XCTest
@testable import KimbiaKit

final class JSONValueTests: XCTestCase {
    func test_encodesAsPlainJSON() throws {
        let value: JSONValue = ["$type": "app.example.activity", "distance": 5000, "pace": 4.5, "indoor": false, "tags": ["a"], "note": nil]

        let decoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]

        XCTAssertEqual(decoded?["$type"] as? String, "app.example.activity")
        XCTAssertEqual(decoded?["distance"] as? Int, 5000)
        XCTAssertEqual(decoded?["pace"] as? Double, 4.5)
        XCTAssertEqual(decoded?["indoor"] as? Bool, false)
        XCTAssertEqual(decoded?["tags"] as? [String], ["a"])
        XCTAssertTrue(decoded?["note"] is NSNull)
    }

    func test_survivesARoundTrip() throws {
        let value: JSONValue = ["n": 1, "x": 1.5, "b": true, "s": "hi", "a": [1, "two"], "o": ["k": nil]]

        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)), value)
    }
}
