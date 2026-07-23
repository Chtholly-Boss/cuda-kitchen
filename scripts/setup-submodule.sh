#!/usr/bin/env bash
# One-shot CUTLASS setup for a fresh clone of cuda-kitchen.
# Safe to re-run.
#
# - cutlass: shallow sparse checkout, include/ only (header-only deps)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CUTLASS="thirdparty/cutlass"
CUTLASS_URL="https://github.com/NVIDIA/cutlass.git"

mkdir -p "$(dirname "$CUTLASS")"

if git -C "$CUTLASS" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$CUTLASS" remote set-url origin "$CUTLASS_URL"
else
    if [ -e "$CUTLASS" ] && [ -n "$(find "$CUTLASS" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "error: $CUTLASS exists but is not a git checkout" >&2
        exit 1
    fi
    rm -rf "$CUTLASS"
    git clone --depth 1 --filter=blob:none --no-tags --no-checkout "$CUTLASS_URL" "$CUTLASS"
fi

# Non-cone mode + /include/* is required: cone mode includes all
# root-level files (README, CMakeLists.txt, etc.) by design.
git -C "$CUTLASS" sparse-checkout init --no-cone
git -C "$CUTLASS" sparse-checkout set "/include/*"

git -C "$CUTLASS" fetch --depth 1 --filter=blob:none --no-tags origin
git -C "$CUTLASS" remote set-head origin --auto >/dev/null 2>&1 || true
DEFAULT_REF="$(git -C "$CUTLASS" symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)"

if [ -n "$DEFAULT_REF" ]; then
    git -C "$CUTLASS" checkout --detach "$DEFAULT_REF"
else
    git -C "$CUTLASS" checkout --detach FETCH_HEAD
fi

echo "cutlass sparse-checkout ready (include/ only)."
