import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "kun.settings.v1"

    var settings: AppSettings {
        didSet {
            save()
            onChange?(settings)
        }
    }

    @ObservationIgnored var onChange: ((AppSettings) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            let migrated = Self.migrated(decoded)
            settings = migrated
            if migrated != decoded {
                save()
            }
        } else {
            settings = .default
        }
    }

    func reset() {
        settings = .default
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    private static func migrated(_ settings: AppSettings) -> AppSettings {
        var migrated = settings
        if migrated.hotkeys == .legacyPRDDefault {
            migrated.hotkeys = .default
        }
        if migrated.openAIModel == AppSettings.openAIModel,
           migrated.openAIBaseURL == AppSettings.openAIBaseURL {
            migrated.openAIModel = AppSettings.deepSeekModel
            migrated.openAIBaseURL = AppSettings.deepSeekBaseURL
            migrated.aiEnhancementEnabled = true
        }
#if !(HAS_APPLE_TRANSLATION)
        if migrated.selectedEngine == .apple {
            migrated.selectedEngine = .openAI
        }
#endif
        return migrated
    }
}
