#!/usr/bin/env bash
set -euo pipefail

archive_path="${ARCHIVE_PATH:-build/AppStore/KUNTranslator.xcarchive}"
export_path="${EXPORT_PATH:-build/AppStore/upload}"
options_plist="${EXPORT_OPTIONS_PLIST:-AppStore/ExportOptions-Upload.plist}"

args=(
  -exportArchive
  -archivePath "$archive_path"
  -exportPath "$export_path"
  -exportOptionsPlist "$options_plist"
  -allowProvisioningUpdates
)

if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

xcodebuild "${args[@]}"

echo "Upload request finished."
