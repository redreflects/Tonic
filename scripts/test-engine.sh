#!/bin/zsh
# Runs the TonicKit engine tests.
#
# Works with only the Xcode Command Line Tools installed: it points the compiler at
# the Swift Testing macro plugin and builds outside the project folder (iCloud
# Desktop sync adds file metadata that breaks code signing of the test bundle).
# Once full Xcode is installed, plain `swift test` inside TonicKit/ should also work.
set -e
cd "$(dirname "$0")/../TonicKit"
PLUGIN=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
EXTRA=()
[[ -f $PLUGIN ]] && EXTRA=(-Xswiftc -load-plugin-library -Xswiftc $PLUGIN)
swift test --scratch-path "${TMPDIR:-/tmp}/tonickit-build" "${EXTRA[@]}" "$@"
