import Foundation

@MainActor
final class OCRCoordinator {
    private let selector: ScreenRegionSelector
    private let captureService: ScreenCaptureService
    private let ocrService: OCRService
    private let assembler = OCRTextAssembler()

    init(
        selector: ScreenRegionSelector,
        captureService: ScreenCaptureService,
        ocrService: OCRService
    ) {
        self.selector = selector
        self.captureService = captureService
        self.ocrService = ocrService
    }

    func captureText() async throws -> String {
        let region = try await selector.selectRegion()
        let image = try await captureService.capture(region: region)
        let blocks = try await ocrService.recognizeText(in: image)
        let text = assembler.assemble(blocks)
        guard !text.isEmpty else { throw KUNError.emptySelection }
        return text
    }
}
