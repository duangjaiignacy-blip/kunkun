import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {
    func capture(region: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.frame.intersects(region) }) ?? content.displays.first else {
            throw KUNError.screenRecordingDenied
        }

        let displayFrame = display.frame
        let localRegion = CGRect(
            x: max(0, region.minX - displayFrame.minX),
            y: max(0, displayFrame.maxY - region.maxY),
            width: region.width,
            height: region.height
        )

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = localRegion
        configuration.width = Int(region.width)
        configuration.height = Int(region.height)
        configuration.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }
}
