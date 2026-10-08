#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-source-focus.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/SourceFocusLogic.swift \
    tests/SourceFocusTests.swift -o "$TEST_DIR/source-focus-tests"
"$TEST_DIR/source-focus-tests"
