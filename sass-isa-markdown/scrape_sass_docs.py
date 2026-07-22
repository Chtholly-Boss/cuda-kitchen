#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "beautifulsoup4",
#   "html2text",
#   "requests",
# ]
# ///
"""
Scrape the Instruction Set Reference section of NVIDIA's CUDA Binary Utilities docs.

Source: https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference

Produces 4 markdown files (one per architecture subsection) under cuda_skill/references/:
  - turing.md       (sm_75)
  - ampere-ada.md   (sm_80/86/87/89)
  - hopper.md       (sm_90)
  - blackwell.md    (sm_100/103/...)

Each file contains the architecture's opcode/description table with category subheadings
preserved. Designed for grep-based lookup.
"""

import re
from pathlib import Path

import html2text
import requests
from bs4 import BeautifulSoup

SOURCE_URL = "https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html"
SECTION_ID = "instruction-set-reference"

SUBSECTION_IDS = [
    "turing-instruction-set",
    "nvidia-ampere-gpu-and-ada-instruction-set",
    "hopper-instruction-set",
    "blackwell-instruction-set",
]

OUTPUT_NAMES = {
    "turing-instruction-set": "turing",
    "nvidia-ampere-gpu-and-ada-instruction-set": "ampere-ada",
    "hopper-instruction-set": "hopper",
    "blackwell-instruction-set": "blackwell",
}

ARCH_COVERAGE = {
    "turing": "sm_75",
    "ampere-ada": "sm_80, sm_86, sm_87, sm_89",
    "hopper": "sm_90",
    "blackwell": "sm_100, sm_103, sm_120, sm_121",
}

# Strip Sphinx's "4.1." style section numbers and any trailing private-use glyphs.
SECTION_NUM_RE = re.compile(r"^\d+(?:\.\d+)+\.?\s*")
# Strip U+F0C1-style private-use icon chars (NVIDIA's permalink glyph) anywhere.
PUA_RE = re.compile(r"[-]")


def make_h2t() -> html2text.HTML2Text:
    h2t = html2text.HTML2Text()
    h2t.body_width = 0
    h2t.ignore_links = False
    h2t.ignore_images = True
    h2t.ignore_emphasis = False
    h2t.skip_internal_links = False
    h2t.unicode_snob = True
    h2t.decode_errors = "ignore"
    h2t.mark_code = True
    return h2t


def fetch_html(url: str) -> bytes:
    """Fetch raw bytes — let BeautifulSoup detect encoding, avoids mojibake from requests' guess."""
    print(f"Fetching: {url}")
    response = requests.get(
        url,
        timeout=30,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        },
    )
    response.raise_for_status()
    return response.content


def clean_heading(text: str) -> str:
    text = PUA_RE.sub("", text)
    text = SECTION_NUM_RE.sub("", text)
    return text.strip()


def strip_noise(soup_element) -> None:
    """Remove Sphinx permalink anchors, table captions, and headerlink artifacts in-place."""
    for tag in soup_element.find_all("a", class_="headerlink"):
        tag.decompose()
    for tag in soup_element.find_all("caption"):
        tag.decompose()


def build_header(arch_name: str, heading_text: str) -> str:
    arch = ARCH_COVERAGE[arch_name]
    return (
        f"# {heading_text}\n\n"
        f"**Architectures:** {arch}\n\n"
        f"**Source:** <{SOURCE_URL}#{SECTION_ID}>\n\n"
        f"<!-- category subheadings preserved from the original table; "
        f"use grep with -A/-B context to find a whole category -->\n\n"
    )


def main() -> None:
    html = fetch_html(SOURCE_URL)
    soup = BeautifulSoup(html, "html.parser")

    section = soup.find(id=SECTION_ID)
    if section is None:
        raise SystemExit(f"Could not find id={SECTION_ID!r} in source page")

    h2t = make_h2t()
    out_dir = Path(__file__).parent / "cuda_skill" / "references"
    out_dir.mkdir(parents=True, exist_ok=True)

    summary = []
    for sub_id in SUBSECTION_IDS:
        subsection = section.find(id=sub_id)
        if subsection is None:
            print(f"WARNING: subsection id={sub_id!r} not found, skipping")
            continue

        heading = subsection.find(["h2", "h3"])
        heading_text = clean_heading(heading.get_text(strip=True)) if heading else sub_id

        table = subsection.find("table")
        if table is None:
            print(f"WARNING: no <table> in {sub_id!r}, skipping")
            continue

        rows = table.find_all("tr")
        row_count = len(rows)

        strip_noise(table)

        arch_name = OUTPUT_NAMES[sub_id]
        body = h2t.handle(str(table)).strip() + "\n"
        body = PUA_RE.sub("", body)

        header = build_header(arch_name, heading_text)
        out_path = out_dir / f"{arch_name}.md"
        out_path.write_text(header + body, encoding="utf-8")

        summary.append(f"  {arch_name:<12} {row_count:>4} rows  ->  {out_path.name}")
        print(f"  wrote {out_path.name} ({row_count} rows)")

    print()
    print("Summary:")
    print("\n".join(summary))


if __name__ == "__main__":
    main()
