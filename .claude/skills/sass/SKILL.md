---
name: sass
description: "SASS (post-PTX GPU assembly) instruction set reference for Claude Code. Use when looking up SASS opcodes, interpreting cuobjdump -sass / nvdisasm output, understanding what HMMA/UTCHMMA/LDG/etc. mean, or comparing instruction availability across NVIDIA architectures (Turing sm_75, Ampere/Ada sm_80-89, Hopper sm_90, Blackwell sm_100/103/120/121). Triggers on SASS, cuobjdump, nvdisasm, opcode lookup, sm_75/sm_80/sm_86/sm_89/sm_90/sm_100/sm_103 instruction set, Blackwell tensor memory, UTC* ops."
---

# SASS Instruction Set Reference Skill

Official NVIDIA SASS opcode → description tables, converted from the CUDA Binary Utilities docs to searchable markdown. Covers four architecture families in four files.

**What this skill is for:** "What does SASS opcode X do?" — look up an opcode you saw in `cuobjdump -sass` or `nvdisasm` output.

**What this skill is NOT for:** SASS latency/throughput numbers (those come from `nvdisasm`'s hidden OPERATION SETS tables via DocumentSASS — see `../../../sm_103a/SM103A_LATENCIES.md` if present), or PTX instructions (use the `cuda` skill's PTX docs).

## File Map

| File | Architectures | Source Table |
|------|---------------|--------------|
| `references/turing.md` | sm_75 | Turing Instruction Set |
| `references/ampere-ada.md` | sm_80, sm_86, sm_87, sm_89 | Ampere GPU and Ada Instruction Set |
| `references/hopper.md` | sm_90 | Hopper Instruction Set |
| `references/blackwell.md` | sm_100, sm_103, sm_120, sm_121 | Blackwell Instruction Set |

Each file is a two-column table (`Opcode | Description`) with bold category subheadings like **Floating Point Instructions**, **Integer Instructions**, **Memory Instructions**, **Texture Instructions**, **Control Instructions**.

## Quick Lookup

Find an opcode across all architectures:
```bash
grep -rn "^HMMA" references/
grep -rn "^UTCHMMA" references/
```

Find an opcode in a specific architecture:
```bash
grep -n "^HMMA" references/hopper.md        # Hopper MMA
grep -n "UTC" references/blackwell.md       # Blackwell tensor-core ops
```

Pull a whole category (e.g., all memory instructions in Blackwell):
```bash
grep -n -A 40 "^\*\*Memory Instructions" references/blackwell.md
```

For deeper navigation — grep recipes by category, cross-arch comparison tips, and common pitfalls — see `references/sass-isa.md`.

## Companion Resources

- **PTX ISA, CUDA Runtime API, CUDA Driver API:** use the `cuda` skill (`references/ptx-docs/`, `references/cuda-runtime-docs/`, `references/cuda-driver-docs/`).
- **SASS latency/throughput on sm_103a:** `../../../sm_103a/SM103A_LATENCIES.md` (extracted via DocumentSASS, not part of this skill).
- **How to regenerate these files:** `../scrape_sass_docs.py` (uv script).

## Source

<https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference> (CUDA 13.3 docs). Unofficial conversion for convenience; refer to NVIDIA's official page for authoritative reference.
