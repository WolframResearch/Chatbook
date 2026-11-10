#!/bin/bash
# Runs Chatbook .wlt test files with a front end available and prints a pass count and the details of each failure.
#
#   ./runtests.sh Tests/FormattingBlocks.wlt [more.wlt ...]
#
# Set CHATBOOK_REPO to test a different checkout (default: the checkout that contains this directory).
here="$(cd "$(dirname "$0")" && pwd)"
export CHATBOOK_REPO="${CHATBOOK_REPO:-$(cd "$here/../.." && pwd)}"
args=()
for f in "$@"; do args+=("$(realpath "$f")"); done
exec "$here/withfe.sh" wolframscript -f "$here/runtests.wls" "${args[@]}"
