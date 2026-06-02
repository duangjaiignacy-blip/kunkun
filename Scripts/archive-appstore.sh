#!/usr/bin/env bash
set -euo pipefail

scheme="${SCHEME:-KUNTranslator-AppStore}"
configuration="${CONFIGURATION:-AppStore}"
archive_path="${ARCHIVE_PATH:-build/AppStore/KUNTranslator.xcarchive}"
derived_data_path="${DERIVED_DATA_PATH:-build/DerivedData-AppStore}"

args=(
  -scheme "$scheme"
  -configuration "$configuration"
  -destination "generic/platform=macOS"
  -archivePath "$archive_path"
  -derivedDataPath "$derived_data_path"
  archive
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  args+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

xcodebuild "${args[@]}"

echo "Created archive: $archive_path"
