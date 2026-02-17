#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

shopt -s nullglob

repo_targets=(
  "${REPO_ROOT}/build"
  "${REPO_ROOT}/.build"
  "${REPO_ROOT}/DerivedData"
)

derived_data_glob=( "${HOME}/Library/Developer/Xcode/DerivedData/Conductor-"* )

all_targets=()
for p in "${repo_targets[@]}"; do
  [[ -e "${p}" ]] && all_targets+=( "${p}" )
done
for p in "${derived_data_glob[@]}"; do
  [[ -e "${p}" ]] && all_targets+=( "${p}" )
done

if [[ ${#all_targets[@]} -eq 0 ]]; then
  echo "No heavy build artifacts found."
  exit 0
fi

echo "Removing heavy build artifacts:"
for p in "${all_targets[@]}"; do
  echo "  ${p}"
  rm -rf "${p}"
done

echo "Done."
