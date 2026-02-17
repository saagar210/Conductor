#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_PATH="${REPO_ROOT}/Conductor.xcodeproj"
SCHEME="Conductor"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"

LEAN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/conductor-lean.XXXXXX")"
DERIVED_DATA_PATH="${LEAN_ROOT}/DerivedData"
SOURCE_PACKAGES_PATH="${LEAN_ROOT}/SourcePackages"

cleanup() {
  if [[ "${LEAN_KEEP_TEMP:-0}" == "1" ]]; then
    echo "LEAN_KEEP_TEMP=1 set; keeping temporary artifacts at: ${LEAN_ROOT}"
    return
  fi

  rm -rf "${LEAN_ROOT}"
}

trap cleanup EXIT INT TERM

echo "Lean build paths:"
echo "  DerivedData: ${DERIVED_DATA_PATH}"
echo "  SourcePackages: ${SOURCE_PACKAGES_PATH}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_PATH}" \
  build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/Conductor.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Expected app was not found at ${APP_PATH}" >&2
  exit 1
fi

if [[ "${LEAN_BUILD_ONLY:-0}" == "1" ]]; then
  echo "LEAN_BUILD_ONLY=1 set; skipping app launch."
  exit 0
fi

echo "Launching ${APP_PATH}"
echo "Artifacts are temporary and will be removed automatically after app exit."
open -W "${APP_PATH}"
