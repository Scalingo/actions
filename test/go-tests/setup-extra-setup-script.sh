#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <target-directory> <success|failure>" >&2
  exit 1
fi

target_directory="$1"
outcome="$2"

case "$outcome" in
  success)
    exit_status=0
    ;;
  failure)
    exit_status=1
    ;;
  *)
    echo "Invalid outcome: '$outcome'. Expected 'success' or 'failure'." >&2
    exit 1
    ;;
esac

mkdir -p "$target_directory/bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'touch .scalingo-ci-extra-setup-ran' \
  "exit $exit_status" > "$target_directory/bin/scalingo-ci-extra-setup.sh"
chmod +x "$target_directory/bin/scalingo-ci-extra-setup.sh"
