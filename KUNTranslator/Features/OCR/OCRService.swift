import Foundation
import Vision

final class OCRService {
    func recognizeText(in image: CGImage) async throws -> [OCRBlock] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: KUNError.underlying(error))
                        return
                    }
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let blocks = observations.compactMap { observation -> OCRBlock? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return OCRBlock(
                            text: candidate.string,
                            boundingBox: observation.boundingBox,
                            confidence: candidate.confidence
                        )
                    }
                    continuation.resume(returning: blocks)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]

                let handler = VNImageRequestHandler(cgImage: image)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: KUNError.underlying(error))
                }
            }
        }
    }
}
