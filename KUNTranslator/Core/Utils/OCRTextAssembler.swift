import Foundation

struct OCRTextAssembler {
    func assemble(_ blocks: [OCRBlock]) -> String {
        blocks
            .sorted { lhs, rhs in
                let lhsY = lhs.boundingBox.midY
                let rhsY = rhs.boundingBox.midY
                if abs(lhsY - rhsY) > 0.03 {
                    return lhsY > rhsY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
