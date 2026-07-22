#!/usr/bin/env bash
# Sparse-checkout CUTLASS include/ only.
# Safe to re-run. Uses `git submodule add` so the gitlink lands in the
# index (manual .gitmodules edits alone are not sufficient).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMOD_PATH="thirdparty/cutlass"
SUBMOD_NAME="cutlass"
URL="https://github.com/NVIDIA/cutlass.git"
SPARSE_DIR="include"

cd "$ROOT"

# 1. Register + clone the submodule if not already known to git.
if ! git submodule status "$SUBMOD_PATH" >/dev/null 2>&1; then
    # --depth 1 keeps the initial clone shallow; shallow=true below
    # keeps future `update --init` (fresh clones of this repo) shallow too.
    # --name makes the .gitmodules section name match SUBMOD_NAME, so the
    # subsequent `git config -f .gitmodules submodule.<name>.shallow` lands
    # in the same section instead of creating a dangling second one.
    git submodule add --name "$SUBMOD_NAME" --depth 1 "$URL" "$SUBMOD_PATH"
    git config -f .gitmodules "submodule.${SUBMOD_NAME}.shallow" "true"
    git add .gitmodules
    echo "Registered ${SUBMOD_NAME} submodule"
else
    # Submodule is already known — make sure it's present on disk.
    git submodule update --init "$SUBMOD_PATH"
fi

# 2. Configure sparse checkout (idempotent). Non-cone mode with an
# explicit /include/* pattern is required: cone mode always includes
# root-level files (README, CMakeLists.txt, etc.), which we don't want.
if ! git -C "$SUBMOD_PATH" config --get core.sparseCheckout >/dev/null 2>&1; then
    git -C "$SUBMOD_PATH" sparse-checkout init --no-cone
fi
git -C "$SUBMOD_PATH" sparse-checkout set "/${SPARSE_DIR}/*"

echo "Ready: $ROOT/$SUBMOD_PATH/$SPARSE_DIR"
