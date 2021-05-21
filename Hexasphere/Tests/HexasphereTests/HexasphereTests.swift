import XCTest
@testable import Hexasphere

final class HexasphereTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Hexasphere(radius: 2.0, numDivisions: 15, hexSize: 2.0).text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
