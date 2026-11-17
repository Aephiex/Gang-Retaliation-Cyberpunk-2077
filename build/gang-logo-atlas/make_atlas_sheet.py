"""Build the Gang Retaliation stronghold banner sheet from a folder of per-gang images.

Usage:
    python -I make_atlas_sheet.py <input_folder> <output_folder> [full|half]

full (default): 1360x575 cells, 4096x2048 sheet (2x the 680x300 display size, sharp on 4K).
half:           680x288 cells,  2048x1024 sheet (1x, a quarter of the pixels; softer on 4K).

Input: one image per gang, named <part>.png (any case); 6thstreet.png and scavs.png are accepted.
Output: <output_folder>/gr_gang_banners[_half].png plus parts[_half].txt / .json with each
part's pixel rectangle, ready to enter in WolvenKit's atlas editor.
"""
import json
import sys
from pathlib import Path

from PIL import Image

MODES = {
    "full": {"cell": (1360, 575), "sheet": (4096, 2048), "suffix": ""},
    "half": {"cell": (680, 288), "sheet": (2048, 1024), "suffix": "_half"},
}
COLUMNS = 3
ALIASES = {"6thstreet": "sixthstreet", "scavs": "scavengers"}  # file name -> part name
PARTS = [
    "animals", "barghest", "maelstrom",
    "scavengers", "sixthstreet", "tygerclaws",
    "valentinos", "voodooboys", "wraiths",
]


def fit(image: Image.Image, cell_w: int, cell_h: int) -> Image.Image:
    """Scale to fit the cell, keeping the aspect ratio, centered on a transparent cell."""
    image = image.convert("RGBA")
    scale = min(cell_w / image.width, cell_h / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    image = image.resize(size, Image.LANCZOS)
    cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    cell.paste(image, ((cell_w - size[0]) // 2, (cell_h - size[1]) // 2), image)
    return cell


def main() -> int:
    if len(sys.argv) not in (3, 4) or (len(sys.argv) == 4 and sys.argv[3] not in MODES):
        print(__doc__)
        return 2
    mode = MODES[sys.argv[3] if len(sys.argv) == 4 else "full"]
    (cell_w, cell_h), (sheet_w, sheet_h), suffix = mode["cell"], mode["sheet"], mode["suffix"]
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)
    files = {ALIASES.get(p.stem.lower(), p.stem.lower()): p
             for p in source.iterdir() if p.suffix.lower() == ".png"}
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    rows, missing = [], []
    for index, part in enumerate(PARTS):
        x, y = (index % COLUMNS) * cell_w, (index // COLUMNS) * cell_h
        if part not in files:
            missing.append(part)
            continue
        sheet.paste(fit(Image.open(files[part]), cell_w, cell_h), (x, y))
        rows.append({
            "part": part, "x": x, "y": y, "width": cell_w, "height": cell_h,
            "u0": x / sheet_w, "v0": y / sheet_h,
            "u1": (x + cell_w) / sheet_w, "v1": (y + cell_h) / sheet_h,
        })
    sheet.save(target / f"gr_gang_banners{suffix}.png")
    (target / f"parts{suffix}.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    lines = [f"sheet {sheet_w}x{sheet_h}, cell {cell_w}x{cell_h}"] + [
        f"{r['part']:<12} x={r['x']:<5} y={r['y']:<5} w={r['width']} h={r['height']}  "
        f"uv=({r['u0']:.6f}, {r['v0']:.6f})-({r['u1']:.6f}, {r['v1']:.6f})" for r in rows]
    if missing:
        lines.append("MISSING (left blank): " + ", ".join(missing))
    (target / f"parts{suffix}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
