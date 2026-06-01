#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Release/KUNTranslator.app}"
DMG_PATH="${2:-KUNTranslator.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 2
fi

rm -f "$DMG_PATH"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
repo_create_dmg="$repo_root/.tools/bin/create-dmg"

can_use_create_dmg() {
  local bin_path="$1"
  local root_dir
  root_dir="$(cd "$(dirname "$bin_path")/.." && pwd)"
  [[ -x "$bin_path" && -d "$root_dir/share/create-dmg/support" ]]
}

if command -v create-dmg >/dev/null 2>&1 && can_use_create_dmg "$(command -v create-dmg)"; then
  create_dmg_bin="$(command -v create-dmg)"
elif can_use_create_dmg "$repo_create_dmg"; then
  create_dmg_bin="$repo_create_dmg"
else
  create_dmg_bin=""
fi

if [[ -n "$create_dmg_bin" ]]; then
  "$create_dmg_bin" \
    --volname "KUN Translator" \
    --window-size 600 400 \
    --icon-size 100 \
    "$DMG_PATH" \
    "$APP_PATH"
else
  staging_dir="$(mktemp -d)"
  trap 'rm -rf "$staging_dir"' EXIT
  cp -R "$APP_PATH" "$staging_dir/"
  ln -s /Applications "$staging_dir/Applications"
  hdiutil create \
    -volname "KUN Translator" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
fi
