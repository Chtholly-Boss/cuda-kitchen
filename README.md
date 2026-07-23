# cuda-kitchen

Workspace for converting NVIDIA CUDA documentation into searchable markdown + Claude Code skills.

## Skills

| Skill | Triggers on | Covers |
|-------|-------------|--------|
| `cuda` | CUDA, GPU kernel, PTX, nsys, ncu, cuda-gdb | PTX ISA + Runtime API + Driver API + profiling workflows |
| `sass` | SASS, `cuobjdump -sass`, `nvdisasm`, opcode lookup | SASS opcode → description tables for sm_75 / sm_80-89 / sm_90 / sm_100-121 |

## Updating Skills

```bash
# PTX/Runtime/Driver docs
cd ptx-isa-markdown && ./scrape_cuda_docs.py
cp -r cuda_skill ../.claude/skills/cuda

# SASS Instruction Set Reference
cd sass-isa-markdown && ./scrape_sass_docs.py
cp -r cuda_skill ../.claude/skills/sass
```

Both scrapers are uv scripts — dependencies install automatically on first run.

## Setup

After a fresh clone, run:

```bash
bash scripts/setup.sh
```

This installs a shallow sparse checkout of CUTLASS into
`thirdparty/cutlass/include/` and writes a local `.clangd` from
`scripts/clangd.template.yaml`. The generated `.clangd` and `thirdparty/`
contents are ignored by git.

`setup.sh` accepts explicit CUDA and GPU architecture settings:

```bash
bash scripts/setup.sh --cuda 13.3 --arch sm_103
```

If `--cuda` or `--arch` is omitted, the script tries to detect them from
`nvcc` and `nvidia-smi`. The script assumes a Linux/MSYS2-style shell and uses
Unix-style paths directly.

If no CUDA toolkit include directory is found, `setup.sh` installs the runtime
headers into `thirdparty/cuda-runtime` with `python3 -m pip` and points
`thirdparty/cuda` at the installed include parent. The package is selected for
the requested CUDA major/minor version. Pass `--skip-cuda` to skip this
project-local CUDA runtime header fallback.

## References

Projects whose structure or data this repo builds on:

- [technillogue/ptx-isa-markdown](https://github.com/technillogue/ptx-isa-markdown) — source of the `cuda` skill (PTX ISA + CUDA Runtime + Driver API conversion). Included as a git submodule.
- [0xD0GF00D/DocumentSASS](https://github.com/0xD0GF00D/DocumentSASS) — extracts SASS instruction encodings and latency tables from `nvdisasm` via memcpy interception. Used for cross-architecture latency analysis (not bundled here).

Source documentation and supplementary references:

- [PTX ISA 9.1](https://docs.nvidia.com/cuda/parallel-thread-execution/) — source for `ptx-isa-markdown` PTX docs.
- [CUDA Runtime API 13.1](https://docs.nvidia.com/cuda/cuda-runtime-api/) — source for Runtime docs.
- [CUDA Driver API 13.1](https://docs.nvidia.com/cuda/cuda-driver-api/) — source for Driver docs.
- [CUDA Binary Utilities — Instruction Set Reference](https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference) — source for the `sass` skill.
- [https://kuterdinel.com/nv_isa/](https://kuterdinel.com/nv_isa/) — community SASS instruction reference, useful for opcode details beyond the official table.
