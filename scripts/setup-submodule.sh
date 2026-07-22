#!/usr/bin/env bash
# One-shot submodule setup for a fresh clone of cuda-kitchen.
# Safe to re-run.
#
# - ptx-isa-markdown: full clone (source of the `cuda` skill)
# - cutlass: sparse checkout, include/ only (header-only deps)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 1. Populate all submodules. Honors shallow=true in .gitmodules.
git submodule update --init --recursive

# 2. Sparse-apply cutlass so only include/ lands on disk.
#    Non-cone mode + /include/* is required: cone mode includes all
#    root-level files (README, CMakeLists.txt, etc.) by design.
CUTLASS="thirdparty/cutlass"
if [ -d "$CUTLASS" ]; then
    if ! git -C "$CUTLASS" config --get core.sparseCheckout >/dev/null 2>&1; then
        git -C "$CUTLASS" sparse-checkout init --no-cone
    fi
    git -C "$CUTLASS" sparse-checkout set "/include/*"
    echo "cutlass sparse-checkout applied (include/ only)"
fi

echo "Submodules ready."
