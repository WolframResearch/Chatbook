#!/bin/bash
# Evaluates a Wolfram Language file in a fresh kernel with Chatbook loaded from source and a front end available.
#
#   ./evalwl.sh probe.wl        (use Print[ToString[expr, InputForm]] for output)
#
# Set CHATBOOK_REPO to use a different checkout (default: the checkout that contains this directory).
here="$(cd "$(dirname "$0")" && pwd)"
export CHATBOOK_REPO="${CHATBOOK_REPO:-$(cd "$here/../.." && pwd)}"
f="$(realpath "$1")"
tmp="$(mktemp --suffix=.wl)"
cat > "$tmp" <<WL
PacletDirectoryLoad[ Environment[ "CHATBOOK_REPO" ] ];
UsingFrontEnd[ Null ];
Get[ "Wolfram\`Chatbook\`" ];
Get[ "$f" ];
WL
"$here/withfe.sh" wolframscript -f "$tmp"
rm -f "$tmp"
