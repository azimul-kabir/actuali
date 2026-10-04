#!/usr/bin/env bash
# Cloud-session setup. Xcode can't run on Linux, so the build/test commands in
# AGENTS.md aren't available here; this gets the pieces that are: SwiftFormat
# (CI-required lint) and the upstream Actual repo used as the sync reference.
set -uo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

if ! command -v swiftformat >/dev/null; then
    tmp=$(mktemp -d)
    if curl -fsSL https://github.com/nicklockwood/SwiftFormat/releases/latest/download/swiftformat_linux.zip -o "$tmp/sf.zip" \
        && unzip -q -o "$tmp/sf.zip" -d "$tmp"; then
        bin=$(find "$tmp" -type f -name 'swiftformat*' ! -name '*.zip' | head -1)
        install -m 0755 "$bin" /usr/local/bin/swiftformat || echo "swiftformat install failed" >&2
    else
        echo "swiftformat download failed" >&2
    fi
    rm -rf "$tmp"
fi

# Reference implementation for CRDT/sync parity checks (gitignored).
[ -d actual ] || git clone --depth 1 https://github.com/actualbudget/actual actual || echo "upstream clone failed" >&2

# Same pre-commit hook the repo asks contributors to install.
bash dev/scripts/install-hooks.sh >/dev/null 2>&1 || true
exit 0
