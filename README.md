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

## Submodule Init

```bash
git clone --recurse-submodules <repo>
# or, after a plain clone:
git submodule update --init --recursive
```

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

## License

Documentation © NVIDIA Corporation. Conversions are unofficial; refer to NVIDIA's official docs for authoritative reference.
