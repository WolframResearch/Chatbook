#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

#echo $SCRIPT_DIR

CHATBOOK_ROOT_DIR=$(dirname "${SCRIPT_DIR}")

#echo $CHATBOOK_ROOT_DIR

cd $CHATBOOK_ROOT_DIR

git restore DarkModeSupport/StyleSheets/Chatbook.nb \
    DarkModeSupport/StyleSheets/Wolfram/WorkspaceChat.nb \
    FrontEnd/Assets/Extensions/CoreExtensions.nb \
    FrontEnd/StyleSheets/Chatbook.nb \
    FrontEnd/StyleSheets/Wolfram/WorkspaceChat.nb

# Deleting *.mx file, *.wxf files, empty build/ directory
wolframscript Scripts/Clean.wls

## END
