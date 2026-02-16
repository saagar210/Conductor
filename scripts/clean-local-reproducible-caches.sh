#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/clean-heavy-build-artifacts.sh"

extra_targets=(
  "${REPO_ROOT}/.swiftpm"
  "${REPO_ROOT}/Conductor.xcodeproj/xcuserdata"
  "${REPO_ROOT}/Conductor.xcodeproj/project.xcworkspace/xcuserdata"
)

echo "Removing additional reproducible local caches:"
removed_any=0
for p in "${extra_targets[@]}"; do
  if [[ -e "${p}" ]]; then
    echo "  ${p}"
    rm -rf "${p}"
    removed_any=1
  fi
done

while IFS= read -r state_file; do
  echo "  ${state_file}"
  rm -f "${state_file}"
  removed_any=1
done < <(find "${REPO_ROOT}" -type f -name "*.xcuserstate" 2>/dev/null)

if [[ "${removed_any}" -eq 0 ]]; then
  echo "  No additional reproducible cache files found."
fi

echo "Done."
