#!/bin/bash
# Runs a harness script with a front end available, against the Chatbook checkout in $CHATBOOK_REPO (default: the
# checkout that contains this directory).
#
#   ./run.sh snapshot [out.wxf] [--files=l0*,!a02*] [--no-stream]
#   ./run.sh compare  [golden.wxf] [--strings] [--files=...] [--max=N]
#   ./run.sh bench    [--out=name] [--cold=default|all|none|files] [--files=...] [--baseline=bench-main.wxf]
#   ./run.sh profile  [--files=...]
here="$(cd "$(dirname "$0")" && pwd)"
cmd="$1"; shift
case "$cmd" in
  snapshot|compare|bench|profile) ;;
  *) echo "usage: $0 snapshot|compare|bench|profile [args...]" >&2; exit 2 ;;
esac
export CHATBOOK_REPO="${CHATBOOK_REPO:-$(cd "$here/../.." && pwd)}"
exec "$here/withfe.sh" wolframscript -f "$here/$cmd.wls" "$@"
