# SASS ISA Search Guide

Each architecture file is a two-column markdown table (`Opcode | Description`) with bolded category subheadings interleaved as single-column rows. Grep works directly on the raw files — no parsing needed.

## File Map

| File | SMs | Why care |
|------|-----|----------|
| `turing.md` | sm_75 | First consumer SASS with tensor cores. Baseline for cross-arch diffs. |
| `ampere-ada.md` | sm_80, sm_86, sm_87, sm_89 | Adds async global→shared (`LDGSTS` / `cp.async`), BF16 MMA. |
| `hopper.md` | sm_90 | Adds `HMMA` warp-group MMA (PTX `wgmma.mma_async`), `TMA` bulk copy, mbarrier, distributed shared memory. |
| `blackwell.md` | sm_100, sm_103, sm_120, sm_121 | Adds tensor memory (TMEM) + `UTC*` tensor-core ops (`UTCHMMA`, `UTCQMMA`, `UTCOMMA`, `UTCCP`, `UTCSHIFT`), CGA barriers, multicast. |

## Grep Recipes

### Find one opcode everywhere

```bash
# Where does HMMA appear?
grep -n "^HMMA " references/
# → hopper.md + blackwell.md (not in Turing/Ampere — they use HMMA variants or different MMA opcodes)

# All UTC* opcodes in Blackwell
grep -n "UTC" references/blackwell.md
```

### Find a whole category

Categories are bolded as single-column rows (`**Floating Point Instructions**`) inside each table. Pull a block with `-A`:

```bash
# All Hopper floating-point opcodes
grep -n -A 40 "^\*\*Floating Point Instructions" references/hopper.md

# All Blackwell memory instructions
grep -n -A 50 "^\*\*Memory Instructions" references/blackwell.md

# Stop at the next category with a sed range or awk — or just eyeball the output.
```

### Cross-arch comparison

```bash
# Did opcode X exist before Blackwell?
grep -l "^X " references/*.md

# All opcodes starting with H (FP16 family) across arches
grep -hn "^H[A-Z]" references/*.md
```

### By mnemonic prefix

```bash
# All MMAs (HMMA, DMMA, BMMA, UMMA, UTCHMMA, ...)
grep -hn "MMA" references/*.md

# All TMA-related (TMA, UIATMA, ...)
grep -hn "TMA" references/*.md

# All barrier ops (BAR, UBAR, UTCBAR)
grep -hn "BAR" references/*.md
```

## Common Pitfalls

- **Opcode suffixes ignored:** SASS modifiers (`.E`, `.EX`, `.RI`, `.IO`, `.RU`, etc.) are stripped in the docs — only the base mnemonic appears. `LDG.E.128` shows up as `LDG`.
- **Description text is terse:** Many entries say "FP32 Add" for both `FADD` and `FADD32I` — the difference is the immediate-operand form. The docs don't spell this out; check the official page for variants.
- **`__HIR*` opcodes are NOT here:** Hidden internal opcodes (`__HIR0X103`, etc.) that show up in nvdisasm output are not documented publicly. For those, see the latency tables in `sm_103a/SM103A_LATENCIES.md`.
- **Table numbering:** NVIDIA reuses table numbers across doc revisions (e.g., Hopper and Blackwell both label as "Table 8"). Don't rely on the caption — we strip it from these files anyway.

## Regenerating

```bash
./scrape_sass_docs.py     # from sass-isa-markdown/
```

Re-fetches the source page and overwrites the 4 files under `cuda_skill/references/`.
