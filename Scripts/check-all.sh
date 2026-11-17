#!/usr/bin/env bash
# Runs TaggedPointerChecks on the host, on wasm, and on wasm-embedded.
#
# Requires a Swift 6.4 toolchain with the matching wasm SDKs installed, e.g.:
#   swiftly install 6.4.0
#   swift sdk install <wasm artifactbundle url>
# See https://www.swift.org/documentation/articles/wasm-getting-started.html
#
# Override the SDK IDs with WASM_SDK / WASM_EMBEDDED_SDK if needed.
#
# Note: the wasm-embedded run prints benign "data race detected" runtime
# warnings for every withUnsafePointer scope. That is an artifact of the
# Embedded Swift SDK, not a test failure: the checks still pass. This script
# only requires a zero exit code plus the PASS marker.
set -euo pipefail
cd "$(dirname "$0")/.."

WASM_SDK="${WASM_SDK:-swift-6.4.0-RELEASE_wasm}"
WASM_EMBEDDED_SDK="${WASM_EMBEDDED_SDK:-swift-6.4.0-RELEASE_wasm-embedded}"

check() {
    local label="$1"
    shift
    echo "== $label: $* =="
    local out
    if out="$("$@" 2>&1)"; then
        if printf '%s\n' "$out" | grep -q "PASS: all TaggedPointer checks passed"; then
            echo "-- $label: PASS"
            return 0
        fi
    fi
    echo "-- $label: FAIL"
    printf '%s\n' "$out"
    return 1
}

check "host" swift run TaggedPointerChecks
check "wasm" swift run --swift-sdk "$WASM_SDK" TaggedPointerChecks
check "wasm-embedded" swift run --swift-sdk "$WASM_EMBEDDED_SDK" TaggedPointerChecks
echo "All platforms passed."
