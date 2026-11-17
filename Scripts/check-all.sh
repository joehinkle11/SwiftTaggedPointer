#!/usr/bin/env bash
# Runs TaggedPointerChecks on the host, on wasm, and on wasm-embedded.
#
# Requires a Swift 6.4 toolchain with the matching wasm SDKs installed, e.g.:
#   swiftly install 6.4.0
#   swift sdk install <wasm artifactbundle url> --checksum <sha256>
# See https://www.swift.org/documentation/articles/wasm-getting-started.html
#
# The wasm legs are executed with wasmtime (https://wasmtime.dev/), which must
# be on PATH. They are built first because both wasm SDKs share one build
# directory, so each binary must be run before the next build overwrites it.
#
# Override the SDK IDs with WASM_SDK / WASM_EMBEDDED_SDK if yours differ.
#
# Note: the wasm-embedded run prints benign "data race detected" runtime
# warnings for every withUnsafePointer scope. That is an artifact of the
# Embedded Swift SDK, not a test failure: the checks still pass. This script
# only requires a zero exit code plus the PASS marker.
set -euo pipefail
cd "$(dirname "$0")/.."

WASM_SDK="${WASM_SDK:-swift-6.4.0-RELEASE_wasm}"
WASM_EMBEDDED_SDK="${WASM_EMBEDDED_SDK:-swift-6.4.0-RELEASE_wasm-embedded}"

if ! command -v wasmtime >/dev/null 2>&1; then
    echo "error: wasmtime is required to run the wasm checks (https://wasmtime.dev/)" >&2
    exit 1
fi

check_host() {
    echo "== host: swift run TaggedPointerChecks =="
    local out
    if out="$(swift run TaggedPointerChecks 2>&1)"; then
        if printf '%s\n' "$out" | grep -q "PASS: all TaggedPointer checks passed"; then
            echo "-- host: PASS"
            return 0
        fi
    fi
    echo "-- host: FAIL"
    printf '%s\n' "$out"
    return 1
}

check_wasm() {
    local label="$1"
    local sdk="$2"
    echo "== $label: $sdk =="
    swift build --swift-sdk "$sdk" --target TaggedPointerChecks
    local bin
    bin="$(swift build --swift-sdk "$sdk" --target TaggedPointerChecks --show-bin-path 2>/dev/null)/TaggedPointerChecks.wasm"
    local out
    if out="$(wasmtime run "$bin" 2>&1)"; then
        if printf '%s\n' "$out" | grep -q "PASS: all TaggedPointer checks passed"; then
            echo "-- $label: PASS"
            return 0
        fi
    fi
    echo "-- $label: FAIL"
    printf '%s\n' "$out"
    return 1
}

check_host
check_wasm "wasm" "$WASM_SDK"
check_wasm "wasm-embedded" "$WASM_EMBEDDED_SDK"
echo "All platforms passed."
