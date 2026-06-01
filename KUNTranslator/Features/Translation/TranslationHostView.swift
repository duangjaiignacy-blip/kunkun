import SwiftUI

#if HAS_APPLE_TRANSLATION && canImport(Translation)
import Translation

struct TranslationHostView: View {
    let engine: AppleTranslationEngine

    var body: some View {
        if #available(macOS 15.0, *) {
            RuntimeTranslationHostView(bridge: engine.runtimeBridge())
        } else {
            EmptyView()
        }
    }
}

@available(macOS 15.0, *)
private struct RuntimeTranslationHostView: View {
    @ObservedObject var bridge: AppleTranslationBridge

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(bridge.configuration) { session in
                await bridge.perform(using: session)
            }
    }
}
#else
struct TranslationHostView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
