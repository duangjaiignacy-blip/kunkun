#!/usr/bin/env bash
set -euo pipefail

archive_path="${ARCHIVE_PATH:-build/AppStore/KUNTranslator.xcarchive}"
export_path="${EXPORT_PATH:-build/AppStore/export}"
options_plist="${EXPORT_OPTIONS_PLIST:-AppStore/ExportOptions.plist}"

args=(
  -exportArchive
  -archivePath "$archive_path"
  -exportPath "$export_path"
  -exportOptionsPlist "$options_plist"
)

if [[ "${ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  args+=(-allowProvisioningUpdates)
fi

if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

xcodebuild "${args[@]}"

echo "Exported App Store package to: $export_path"
