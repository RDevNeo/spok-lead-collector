#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# The project has no dependencies to install: it is a single userscript with no
# build step and no package.json. This hook only confirms the toolchain is there
# and reports the script's health, so problems surface at the start of a session.
# Checks warn rather than fail, so a broken branch still opens a usable session.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

SCRIPT="lead-collector.user.js"

if ! command -v node > /dev/null 2>&1; then
  echo "session-start: node not found; syntax checks via 'node --check $SCRIPT' are unavailable" >&2
  exit 0
fi
echo "session-start: node $(node --version)"

if node --check "$SCRIPT"; then
  echo "session-start: $SCRIPT syntax OK"
else
  echo "session-start: WARNING - $SCRIPT has a syntax error (see above)" >&2
fi

header="$(grep -oE '^// @version[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' "$SCRIPT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
body="$(grep -oE 'const SCRIPT_VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' "$SCRIPT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
if [ -n "$header" ] && [ "$header" = "$body" ]; then
  echo "session-start: version $header (@version and SCRIPT_VERSION in sync)"
else
  echo "session-start: WARNING - @version '$header' and SCRIPT_VERSION '$body' differ" >&2
fi
