# SASS Instruction Set Reference (Markdown)

NVIDIA's CUDA Binary Utilities "Instruction Set Reference" section converted to searchable markdown, packaged as a Claude Code skill.

## What's Here

The four SASS opcode → description tables, one file per architecture:

| File | Architectures | Rows |
|------|---------------|------|
| `cuda_skill/references/turing.md` | sm_75 | 175 |
| `cuda_skill/references/ampere-ada.md` | sm_80, sm_86, sm_87, sm_89 | 181 |
| `cuda_skill/references/hopper.md` | sm_90 | 218 |
| `cuda_skill/references/blackwell.md` | sm_100, sm_103, sm_120, sm_121 | 259 |

## Why

The source is a single 194KB Sphinx HTML page (`https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference`) — painful to Ctrl+F through. This conversion enables `grep -n "^UTCHMMA" cuda_skill/references/blackwell.md` instead, and lets Claude Code look up SASS opcodes directly without web access.

Mirrors the structure of [`technillogue/ptx-isa-markdown`](https://github.com/technillogue/ptx-isa-markdown), scoped to just the Instruction Set Reference section.

## Structure

```
sass-isa-markdown/
├── README.md                 # this file
├── scrape_sass_docs.py       # uv script — regenerates the 4 markdown files
└── cuda_skill/               # portable skill payload
    ├── SKILL.md              # Claude Code skill definition
    └── references/
        ├── INDEX.md          # one-line per arch with row count
        ├── sass-isa.md       # search guide with grep recipes
        ├── turing.md
        ├── ampere-ada.md
        ├── hopper.md
        └── blackwell.md
```

## Using the Skill

Install to a project:
```bash
cp -r cuda_skill /path/to/project/.claude/skills/sass
```

The skill activates automatically for SASS / `cuobjdump -sass` / `nvdisasm` queries. Ask Claude:
- "What does the SASS opcode `UTCHMMA` do?"
- "Is `HMMA` available on sm_80?"
- "List all Blackwell tensor memory instructions"
- "Compare `TMA` across Hopper and Blackwell"

## Regenerating

```bash
./scrape_sass_docs.py
```

Requires [uv](https://docs.astral.sh/uv/) — dependencies (`beautifulsoup4`, `html2text`, `requests`) are declared inline in the script and installed automatically on first run.

## Source & License

- **Source:** <https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference> (CUDA 13.3 docs)
- **License:** Documentation © NVIDIA Corporation. Unofficial conversion for convenience.
