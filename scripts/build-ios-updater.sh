#!/usr/bin/env bash
# Cross-compile the Shorebird updater library as an iOS XCFramework.
# Outputs:
#   build/ios/libupdater.xcframework     # for engine consumption
#   target/aarch64-apple-ios/release/libupdater.a
#   target/aarch64-apple-ios-sim/release/libupdater.a
#
# Prereqs: Xcode command-line tools; `rustup` on $PATH.
#
# Runs in ~15-30 min cold (downloads all the crates), ~30 s warm.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"

# Source rustup env if the user is running from a shell that doesn't
# auto-source it (macOS, fresh install).
if ! command -v cargo >/dev/null; then
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
fi
command -v cargo >/dev/null || { echo "cargo not on PATH; install via rustup"; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode command-line tools required"; exit 1; }

TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim)

# Install missing targets; rustup's `target add` is idempotent.
for t in "${TARGETS[@]}"; do rustup target add "$t" >/dev/null; done

# ───────────────────────────────────────────────────────────────────────────
# Why IPHONEOS_DEPLOYMENT_TARGET is set:
#   Rust 1.95 + the bundled iOS SDK needs `__chkstk_darwin` (iOS 8.0+).
#   Without this env var, cargo's default min-version produces a cdylib
#   link step that can't resolve that symbol. We only actually ship the
#   staticlib, but cargo still builds the cdylib by default.
# ───────────────────────────────────────────────────────────────────────────
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-12.0}"

cd "$repo"
for t in "${TARGETS[@]}"; do
  echo "▶ building libupdater.a for $t"
  cargo build --release -p updater --target "$t" --lib
done

out="$repo/build/ios/libupdater.xcframework"
rm -rf "$out"
mkdir -p "$(dirname "$out")"

# XCFramework: one slice per (OS, environment). The simulator arm64
# and device arm64 share a CPU arch but are DIFFERENT environments;
# lipo cannot merge them, but xcframework can.
xcodebuild -create-xcframework \
  -library "$repo/target/aarch64-apple-ios/release/libupdater.a" \
    -headers "$repo/library/include" \
  -library "$repo/target/aarch64-apple-ios-sim/release/libupdater.a" \
    -headers "$repo/library/include" \
  -output "$out" >/dev/null

echo
echo "✓ $out"
du -sh "$out"
echo
echo "next: wire into the engine by setting the 'updater' dep path in"
echo "  engine/src/flutter/third_party/updater/BUILD.gn"
echo "  (or the equivalent in your 2023dev/flutter fork)"
