# SASS Instruction Set Reference — Index

Official NVIDIA SASS opcode/description tables, one file per architecture family.

| File | Architectures | Row Count | Notes |
|------|---------------|-----------|-------|
| [turing.md](turing.md) | sm_75 | 175 | Baseline consumer-grade SASS (2018). No tensor memory, no UTC* ops. |
| [ampere-ada.md](ampere-ada.md) | sm_80, sm_86, sm_87, sm_89 | 181 | Adds first-gen tensor core variants, async copies. |
| [hopper.md](hopper.md) | sm_90 | 218 | Adds `HMMA` warp-group MMA, `TMA` async bulk copies, distributed shared memory, mbarrier. |
| [blackwell.md](blackwell.md) | sm_100, sm_103, sm_120, sm_121 | 259 | Adds `UTC*` tensor-core ops (`UTCHMMA`, `UTCQMMA`, `UTCOMMA`, `UTCCP`, `UTCSHIFT`), tensor memory (TMEM), CGA barriers. |

**Source:** <https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference>

**Search guide:** [sass-isa.md](sass-isa.md) — grep recipes by category and cross-arch comparison tips.
