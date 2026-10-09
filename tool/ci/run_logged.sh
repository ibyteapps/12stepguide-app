#!/usr/bin/env bash
# Runs a command and, if it fails, repeats the last lines of its output as a GitHub Actions
# error annotation. Annotations appear on the run summary and through the checks API, so a
# failure can be diagnosed without downloading the full log.
#
#   tool/ci/run_logged.sh "Build dev APK" flutter build apk --debug --flavor dev
set -uo pipefail

title="$1"
shift
log="$(mktemp)"

"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
  # Escape for workflow commands: % first, then CR and LF.
  tail_text="$(tail -n 60 "$log" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | awk '{printf "%s%%0A", $0}')"
  echo "::error title=${title} failed (exit ${status})::${tail_text}"
fi
rm -f "$log"
exit "$status"
