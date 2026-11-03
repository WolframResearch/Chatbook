#!/bin/bash
# Runs a command so that the kernels it starts can launch a front end. Wolfram Language code blocks are formatted
# with a front end call (FrontEnd`ReparseBoxStructurePacket), so the harness and the formatting tests need one.
#
# On Linux without a display, the command runs under xvfb-run. T3CODE_THREAD_ID is removed from the environment:
# T3 Code probes the listening ports of processes that have it, and a front end started from an agent thread then
# loses its kernel at startup. The X11/segfault noise that the Xvfb front end prints when it shuts down is filtered out.
runner=()
if [ "$(uname)" = "Linux" ] && [ -z "$DISPLAY" ] && command -v xvfb-run >/dev/null; then
  runner=(xvfb-run -a)
fi
exec env -u T3CODE_THREAD_ID "${runner[@]}" "$@" \
  2> >(grep -v "XIO\|WolframNB()\|libML64\|libc.so\|libQt\|libX11\|after [0-9]* requests\|SIGSEGV\|Segmentation fault\|please report this problem\|describing in as much detail\|when the problem occurred\|has received the signal\|^\s*$" >&2)
