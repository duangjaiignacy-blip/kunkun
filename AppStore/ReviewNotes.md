# App Store Review Notes

KUN Translator is a macOS productivity app for user-initiated translation.

## Core User Flow

1. Open the app from Applications.
2. Grant Accessibility only when using selected-text translation.
3. Grant Screen Recording only when using screenshot OCR translation.
4. Configure an OpenAI-compatible endpoint such as DeepSeek in Settings > AI.
5. Select text in another app and use the configured shortcut, or use screenshot OCR from the menu bar.

## Permission Rationale

- Accessibility: reads the user's currently selected text after an explicit keyboard shortcut or menu command.
- Screen Recording: captures only the user-selected screen rectangle for OCR translation.
- Network Client: sends translation requests to the user-configured translation provider.

## Privacy Notes

- The app does not track users.
- The app does not create user accounts.
- API keys are stored in the macOS Keychain.
- Translation history and notes are stored locally in the app container.
- Selected text or OCR text is transmitted only when the user starts a translation action.

## Sandbox

The App Store build uses `KUNTranslator-AppStore.entitlements` and enables App Sandbox plus outgoing network client access.
