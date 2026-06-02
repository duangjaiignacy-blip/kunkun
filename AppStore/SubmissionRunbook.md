# App Store Submission Runbook

## 1. Prerequisites

- Apple Developer Program membership.
- `com.kun.translator` created or available in Certificates, Identifiers & Profiles.
- App Store Connect app record created for the same bundle identifier.
- Xcode account logged in, or an App Store Connect API key available.

## 2. Archive With Xcode Account

```bash
.tools/bin/xcodegen generate
DEVELOPMENT_TEAM=YOUR_TEAM_ID ALLOW_PROVISIONING_UPDATES=1 Scripts/archive-appstore.sh
```

## 3. Archive With App Store Connect API Key

```bash
export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.tools/bin/xcodegen generate
DEVELOPMENT_TEAM=YOUR_TEAM_ID ALLOW_PROVISIONING_UPDATES=1 Scripts/archive-appstore.sh
```

## 4. Export A Local App Store Package

```bash
Scripts/export-appstore.sh
```

## 5. Upload To App Store Connect

```bash
Scripts/upload-appstore.sh
```

## Current Local Blocker

This Mac currently has only the local signing identity `KUN Translator Local Signing`.
`xcodebuild archive` stops at:

```text
Signing for "KUNTranslator" requires a development team.
```

Add an Apple Developer Team in Xcode Settings > Accounts, or provide `DEVELOPMENT_TEAM`, `ASC_KEY_PATH`, `ASC_KEY_ID`, and `ASC_ISSUER_ID`.
