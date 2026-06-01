import CoreGraphics
import XCTest

final class OCRTextAssemblerTests: XCTestCase {
    func testAssemblerSortsTopToBottomThenLeftToRight() {
        let blocks = [
            OCRBlock(text: "world", boundingBox: CGRect(x: 0.5, y: 0.8, width: 0.2, height: 0.1), confidence: 0.9),
            OCRBlock(text: "Hello", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.1), confidence: 0.9),
            OCRBlock(text: "Second", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.1), confidence: 0.9)
        ]

        let text = OCRTextAssembler().assemble(blocks)

        XCTAssertEqual(text, "Hello\nworld\nSecond")
    }
}
