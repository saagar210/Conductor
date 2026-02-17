#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Repo: ${REPO_ROOT}"
echo

echo "Repository-local paths:"
du -sh \
  "${REPO_ROOT}" \
  "${REPO_ROOT}/build" \
  "${REPO_ROOT}/.build" \
  "${REPO_ROOT}/DerivedData" \
  "${REPO_ROOT}/.swiftpm" \
  2>/dev/null || true

echo
echo "Xcode global paths:"
du -sh \
  "${HOME}/Library/Developer/Xcode/DerivedData" \
  "${HOME}/Library/Developer/Xcode/DerivedData/Conductor-"* \
  2>/dev/null || true
