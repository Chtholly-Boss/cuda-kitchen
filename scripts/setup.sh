#!/usr/bin/env bash
# One-shot local setup for CUDA/CUTLASS editing.
# Safe to re-run.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  bash scripts/setup.sh [--cuda <major.minor>] [--arch <sm_xx>] [options]

Examples:
  bash scripts/setup.sh
  bash scripts/setup.sh --cuda 13.3 --arch sm_103
  bash scripts/setup.sh --cuda 12.8 --arch sm_90

Options:
  --cuda <version>   CUDA version, for example 13.3 or 12.8.
                     If omitted, detect from nvcc, then nvidia-smi.
  --arch <sm_xx>     CUDA GPU architecture, for example sm_90 or sm_103.
                     If omitted, detect first GPU via nvidia-smi.
  --skip-cuda        Do not install runtime headers under thirdparty/cuda-runtime.
  --skip-cutlass     Do not clone/update thirdparty/cutlass.
  --skip-clangd      Do not write .clangd.
  -h, --help         Show this help.

CUDA toolkit root is detected from CUDA_PATH, nvcc, and /usr/local/cuda.
If missing, runtime headers are installed under thirdparty/cuda-runtime.
EOF
}

die() {
    echo "error: $*" >&2
    echo >&2
    usage >&2
    exit 1
}

warn() {
    echo "warning: $*" >&2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

CUDA_VERSION=""
ARCH=""
INSTALL_CUDA=1
SKIPPED_CUDA_INSTALL=0
INSTALL_CUTLASS=1
WRITE_CLANGD=1

while [ "$#" -gt 0 ]; do
    case "$1" in
        --cuda)
            [ "$#" -ge 2 ] || die "--cuda requires a value"
            CUDA_VERSION="$2"
            shift 2
            ;;
        --arch)
            [ "$#" -ge 2 ] || die "--arch requires a value"
            ARCH="$2"
            shift 2
            ;;
        --skip-cutlass)
            INSTALL_CUTLASS=0
            shift
            ;;
        --skip-cuda)
            INSTALL_CUDA=0
            shift
            ;;
        --skip-clangd)
            WRITE_CLANGD=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

detect_cuda_version() {
    local nvcc_path=""
    local version_line=""

    if command -v nvcc >/dev/null 2>&1; then
        nvcc_path="$(command -v nvcc)"
    elif [ -x /usr/local/cuda/bin/nvcc ]; then
        nvcc_path="/usr/local/cuda/bin/nvcc"
    fi

    if [ -n "$nvcc_path" ]; then
        version_line="$("$nvcc_path" --version | grep "release" || true)"
        if [[ "$version_line" =~ release[[:space:]]+([0-9]+)[.]([0-9]+) ]]; then
            printf '%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
        warn "failed to parse CUDA version from nvcc output: $version_line"
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        version_line="$(nvidia-smi 2>/dev/null | grep -o "CUDA Version: [0-9.]*" | head -n1 || true)"
        if [[ "$version_line" =~ CUDA[[:space:]]Version:[[:space:]]+([0-9]+)[.]([0-9]+) ]]; then
            printf '%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            return 0
        fi
        warn "failed to parse CUDA version from nvidia-smi output"
    fi

    return 1
}

detect_cuda_path() {
    local nvcc_path=""
    local candidate=""
    local version_short="${CUDA_MAJOR}.${CUDA_MINOR}"
    local candidates=()

    if [ -n "${CUDA_PATH:-}" ]; then
        candidates+=("$CUDA_PATH")
    fi

    if command -v nvcc >/dev/null 2>&1; then
        nvcc_path="$(command -v nvcc)"
        candidates+=("$(cd "$(dirname "$nvcc_path")/.." && pwd -P)")
    elif [ -x /usr/local/cuda/bin/nvcc ]; then
        candidates+=("/usr/local/cuda")
    fi

    candidates+=(
        "/usr/local/cuda-${version_short}"
        "/usr/local/cuda"
    )

    for candidate in "${candidates[@]}"; do
        [ -n "$candidate" ] || continue
        if [ -d "$candidate/include" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_cuda_runtime_root() {
    local target="$1"
    local header=""
    local include_dir=""

    header="$(find "$target" -type f -path "*/include/cuda_runtime.h" -print -quit 2>/dev/null || true)"
    if [ -n "$header" ]; then
        include_dir="$(dirname "$header")"
        dirname "$include_dir"
        return 0
    fi

    include_dir="$(find "$target" -type d -name include -print -quit 2>/dev/null || true)"
    if [ -n "$include_dir" ]; then
        dirname "$include_dir"
        return 0
    fi

    return 1
}

cuda_runtime_package_spec() {
    case "$CUDA_MAJOR" in
        12)
            printf 'nvidia-cuda-runtime-cu12==%s.%s.*\n' "$CUDA_MAJOR" "$CUDA_MINOR"
            ;;
        *)
            printf 'nvidia-cuda-runtime==%s.%s.*\n' "$CUDA_MAJOR" "$CUDA_MINOR"
            ;;
    esac
}

install_cuda_runtime_headers() {
    local target="thirdparty/cuda-runtime"
    local link="thirdparty/cuda"
    local runtime_root=""
    local package_spec=""

    command -v python3 >/dev/null 2>&1 || die "python3 not found"

    mkdir -p "$target"

    runtime_root="$(find_cuda_runtime_root "$target" || true)"
    if [ -z "$runtime_root" ]; then
        package_spec="$(cuda_runtime_package_spec)"
        echo "installing CUDA runtime headers into $target" >&2
        python3 -m pip install \
            --no-deps \
            --only-binary=:all: \
            --target "$target" \
            "$package_spec" >&2
        runtime_root="$(find_cuda_runtime_root "$target" || true)"
    fi

    [ -n "$runtime_root" ] || die "failed to locate CUDA runtime include directory under $target"
    [ -d "$runtime_root/include" ] || die "CUDA runtime root is missing include/: $runtime_root"

    if [ -e "$link" ] && [ ! -L "$link" ]; then
        die "$link exists but is not a symlink"
    fi

    ln -sfn "$ROOT/$runtime_root" "$link"
    printf '%s\n' "$ROOT/$link"
}

detect_arch() {
    local cap=""

    if ! command -v nvidia-smi >/dev/null 2>&1; then
        return 1
    fi

    cap="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n1 | tr -d '[:space:].' || true)"
    if [[ "$cap" =~ ^[0-9]+$ ]]; then
        printf 'sm_%s\n' "$cap"
        return 0
    fi

    return 1
}

install_cutlass() {
    local cutlass="thirdparty/cutlass"
    local cutlass_url="https://github.com/NVIDIA/cutlass.git"
    local default_ref=""

    mkdir -p "$(dirname "$cutlass")"

    if git -C "$cutlass" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$cutlass" remote set-url origin "$cutlass_url"
    else
        if [ -e "$cutlass" ] && [ -n "$(find "$cutlass" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            die "$cutlass exists but is not a git checkout"
        fi
        rm -rf "$cutlass"
        git clone --depth 1 --filter=blob:none --no-tags --no-checkout "$cutlass_url" "$cutlass"
    fi

    # Non-cone mode + /include/* is required: cone mode includes all
    # root-level files (README, CMakeLists.txt, etc.) by design.
    git -C "$cutlass" sparse-checkout init --no-cone
    git -C "$cutlass" sparse-checkout set "/include/*"

    git -C "$cutlass" fetch --depth 1 --filter=blob:none --no-tags origin
    git -C "$cutlass" remote set-head origin --auto >/dev/null 2>&1 || true
    default_ref="$(git -C "$cutlass" symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)"

    if [ -n "$default_ref" ]; then
        git -C "$cutlass" checkout --detach "$default_ref"
    else
        git -C "$cutlass" checkout --detach FETCH_HEAD
    fi

    echo "cutlass sparse-checkout ready (include/ only)."
}

if [ -z "$CUDA_VERSION" ]; then
    CUDA_VERSION="$(detect_cuda_version)" || die "could not detect CUDA version; pass --cuda <version>"
fi

if [[ ! "$CUDA_VERSION" =~ ^([0-9]+)[.]([0-9]+)$ ]]; then
    die "--cuda must look like 13.3 or 12.8"
fi

CUDA_MAJOR="${BASH_REMATCH[1]}"
CUDA_MINOR="${BASH_REMATCH[2]}"

if [ -z "$ARCH" ]; then
    ARCH="$(detect_arch)" || die "could not detect GPU architecture; pass --arch <sm_xx>"
fi

if [[ ! "$ARCH" =~ ^sm_([0-9]+)$ ]]; then
    die "--arch must look like sm_90 or sm_103"
fi

ARCH_SM="${BASH_REMATCH[1]}"
CUDA_ARCH_VAL="${ARCH_SM}0"
CUDA_FEATURE_TAG="CUDA_${CUDA_MAJOR}_${CUDA_MINOR}_SM${ARCH_SM}_FEATURES_SUPPORTED"

if CUDA_ROOT="$(detect_cuda_path)"; then
    :
elif [ "$INSTALL_CUDA" -eq 1 ]; then
    CUDA_ROOT="$(install_cuda_runtime_headers)"
else
    CUDA_ROOT="/usr/local/cuda"
    SKIPPED_CUDA_INSTALL=1
fi

CUDA_INCLUDE="$CUDA_ROOT/include"
CUDA_CCCL_INCLUDE="$CUDA_INCLUDE/cccl"

echo "Using CUDA version: ${CUDA_MAJOR}.${CUDA_MINOR}"
echo "Using CUDA arch: ${ARCH} (__CUDA_ARCH__=${CUDA_ARCH_VAL})"
echo "Using CUDA path: $CUDA_ROOT"

if [ ! -d "$CUDA_INCLUDE" ] && [ "$SKIPPED_CUDA_INSTALL" -eq 1 ]; then
    warn "CUDA include directory not found: $CUDA_INCLUDE (--skip-cuda set, not installing runtime headers)"
elif [ ! -d "$CUDA_INCLUDE" ]; then
    warn "CUDA include directory not found: $CUDA_INCLUDE"
fi

if [ "$INSTALL_CUTLASS" -eq 1 ]; then
    install_cutlass
elif [ ! -d "$ROOT/thirdparty/cutlass/include" ]; then
    warn "thirdparty/cutlass/include is missing"
fi

if [ "$WRITE_CLANGD" -eq 1 ]; then
    command -v python3 >/dev/null 2>&1 || die "python3 not found"

    template="$ROOT/scripts/clangd.template.yaml"
    out="$ROOT/.clangd"

    [ -f "$template" ] || die "missing template: $template"

    export CLANGD_TEMPLATE="$template"
    export CLANGD_OUT="$out"
    export CLANGD_REPO_ROOT
    export CLANGD_CUDA_PATH
    export CLANGD_CUDA_INCLUDE
    export CLANGD_CUDA_CCCL_INCLUDE
    export CLANGD_CUDA_GPU_ARCH="$ARCH"
    export CLANGD_CUDA_ARCH_SM="$ARCH_SM"
    export CLANGD_CUDA_ARCH_VAL="$CUDA_ARCH_VAL"
    export CLANGD_CUDA_FEATURE_TAG="$CUDA_FEATURE_TAG"
    export CLANGD_CUDA_MAJOR="$CUDA_MAJOR"
    export CLANGD_CUDA_MINOR="$CUDA_MINOR"

    CLANGD_REPO_ROOT="$ROOT"
    CLANGD_CUDA_PATH="$CUDA_ROOT"
    CLANGD_CUDA_INCLUDE="$CUDA_INCLUDE"
    CLANGD_CUDA_CCCL_INCLUDE="$CUDA_CCCL_INCLUDE"

    python3 - <<'PY'
from pathlib import Path
import os

template = Path(os.environ["CLANGD_TEMPLATE"])
out = Path(os.environ["CLANGD_OUT"])

text = template.read_text(encoding="utf-8")
replacements = {
    "__REPO_ROOT__": os.environ["CLANGD_REPO_ROOT"],
    "__CUDA_PATH__": os.environ["CLANGD_CUDA_PATH"],
    "__CUDA_INCLUDE__": os.environ["CLANGD_CUDA_INCLUDE"],
    "__CUDA_CCCL_INCLUDE__": os.environ["CLANGD_CUDA_CCCL_INCLUDE"],
    "__CUDA_GPU_ARCH__": os.environ["CLANGD_CUDA_GPU_ARCH"],
    "__CUDA_ARCH_SM__": os.environ["CLANGD_CUDA_ARCH_SM"],
    "__CUDA_ARCH_VAL__": os.environ["CLANGD_CUDA_ARCH_VAL"],
    "__CUDA_FEATURE_TAG__": os.environ["CLANGD_CUDA_FEATURE_TAG"],
    "__CUDA_MAJOR__": os.environ["CLANGD_CUDA_MAJOR"],
    "__CUDA_MINOR__": os.environ["CLANGD_CUDA_MINOR"],
}

for old, new in replacements.items():
    text = text.replace(old, new)

out.write_text(text, encoding="utf-8", newline="\n")
PY

    echo "wrote .clangd"
fi

echo "setup complete."
