"""Recover the embedded TSW manifest from Steam HD tsw_index.ssmod.

Requires: pip install zstandard==0.25.0
The script only writes files below this gallery directory; it never changes the game package.
"""

from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path

import zstandard


GALLERY_ROOT = Path(__file__).resolve().parent
PNG_ROOT = GALLERY_ROOT / "hd_tsw_png"
ZSTD_MAGIC = bytes.fromhex("28B52FFD")
TYPE_NAMES = {"1": "char", "2": "item", "3": "effect", "4": "system", "5": "map1", "6": "map2", "8": "hga"}
EXPECTED_MANIFEST_ROWS = 20_991
EXPECTED_PNG_FILES = 20_554
EXPECTED_MISSING_ASSETS = 9


def parse_manifest(raw: bytes) -> list[dict[str, str]]:
    text = raw.decode("utf-8-sig")
    if not text.startswith("MODName "):
        raise ValueError("First Zstandard frame is not a TSW manifest.")
    rows: list[dict[str, str]] = []
    for line in text.splitlines():
        if not line.startswith("TSW "):
            continue
        fields = line[4:].split(",", 5)
        if len(fields) != 6:
            raise ValueError(f"Malformed TSW line: {line!r}")
        tsw_id, sn, asset_type, lang_id, asset_file, comment = (part.strip() for part in fields)
        rows.append(
            {
                "TswId": tsw_id,
                "SN": sn,
                "Type": asset_type,
                "TypeName": TYPE_NAMES.get(asset_type, "unknown"),
                "LangId": lang_id,
                "AssetFile": asset_file,
                "Comment": comment,
            }
        )
    if not rows:
        raise ValueError("No TSW rows found in recovered manifest.")
    return rows


def target_name(original_png: str, bindings: set[tuple[str, str]]) -> str:
    ordered = sorted(bindings, key=lambda pair: (int(pair[0]), int(pair[1])))
    prefix = "__".join(f"TSW{int(tsw_id):05d}-SN{int(sn):02d}" for tsw_id, sn in ordered)
    return f"HD-{prefix}__{original_png}"


def write_csv(path: Path, rows: list[dict[str, str]], fields: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python Extract-HdTswManifest.py <game-root>\\tsw_index.ssmod")
    package = Path(sys.argv[1])
    if not package.is_file():
        raise FileNotFoundError(f"Steam HD package not found: {package}")
    if not PNG_ROOT.is_dir():
        raise FileNotFoundError(f"HD PNG gallery not found: {PNG_ROOT}")

    package_bytes = package.read_bytes()
    frame_offset = package_bytes.find(ZSTD_MAGIC)
    if frame_offset < 0:
        raise ValueError("No Zstandard frame found in SSMOD.")
    manifest_bytes = zstandard.ZstdDecompressor().decompress(package_bytes[frame_offset:])
    manifest_path = GALLERY_ROOT / "tsw_index_hd.ext"
    manifest_rows = parse_manifest(manifest_bytes)
    if len(manifest_rows) != EXPECTED_MANIFEST_ROWS:
        raise ValueError(
            f"Unexpected manifest row count: expected={EXPECTED_MANIFEST_ROWS}, actual={len(manifest_rows)}"
        )

    gallery_png_count = sum(1 for path in PNG_ROOT.glob("*.png") if path.is_file())
    if gallery_png_count != EXPECTED_PNG_FILES:
        raise ValueError(
            f"Unexpected gallery PNG count: expected={EXPECTED_PNG_FILES}, actual={gallery_png_count}"
        )

    bindings_by_original_png: dict[str, set[tuple[str, str]]] = defaultdict(set)
    rows_by_original_png: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in manifest_rows:
        original_png = str(Path(row["AssetFile"]).with_suffix(".png"))
        row["OriginalPngFile"] = original_png
        bindings_by_original_png[original_png].add((row["TswId"], row["SN"]))
        rows_by_original_png[original_png].append(row)

    final_names: dict[str, str] = {}
    for original_png, bindings in bindings_by_original_png.items():
        final_names[original_png] = target_name(original_png, bindings)

    available = 0
    for original_png, final_name in final_names.items():
        source_exists = (PNG_ROOT / original_png).is_file()
        target_exists = (PNG_ROOT / final_name).is_file()
        if source_exists and target_exists and original_png != final_name:
            raise FileExistsError(f"Both source and renamed PNG exist: {original_png}")
        if source_exists or target_exists:
            available += 1
    unavailable = len(final_names) - available
    if available != EXPECTED_PNG_FILES or unavailable != EXPECTED_MISSING_ASSETS:
        raise ValueError(
            "HD gallery preflight failed: "
            f"available={available}, expected_available={EXPECTED_PNG_FILES}, "
            f"missing={unavailable}, expected_missing={EXPECTED_MISSING_ASSETS}"
        )

    manifest_path.write_bytes(manifest_bytes)

    # The manifest is authoritative. Rename only gallery copies, never source package files.
    for original_png, final_name in final_names.items():
        source = PNG_ROOT / original_png
        target = PNG_ROOT / final_name
        if source.exists() and source != target:
            if target.exists():
                raise FileExistsError(f"Refusing to overwrite existing PNG: {target.name}")
            source.rename(target)
        elif not target.exists():
            # Nine manifest assets are absent from the extracted package; do not fabricate previews.
            continue

    mapping_rows: list[dict[str, str]] = []
    for row in manifest_rows:
        final_name = final_names[row["OriginalPngFile"]]
        mapping_rows.append(
            {
                **row,
                "PngFile": final_name,
                "PngExists": str((PNG_ROOT / final_name).is_file()),
                "Verification": "embedded_hd_manifest",
                "Evidence": "Recovered from first Zstandard frame of Steam HD tsw_index.ssmod.",
            }
        )
    write_csv(
        GALLERY_ROOT / "hd_tsw_mapping.csv",
        mapping_rows,
        ["TswId", "SN", "Type", "TypeName", "LangId", "AssetFile", "OriginalPngFile", "PngFile", "Comment", "PngExists", "Verification", "Evidence"],
    )

    inventory_rows: list[dict[str, str]] = []
    for original_png, bindings in sorted(bindings_by_original_png.items(), key=lambda item: item[0].lower()):
        final_name = final_names[original_png]
        inventory_rows.append(
            {
                "OriginalPngFile": original_png,
                "PngFile": final_name,
                "TswBindings": "; ".join(f"{tsw_id}/{sn}" for tsw_id, sn in sorted(bindings, key=lambda pair: (int(pair[0]), int(pair[1])))),
                "PngExists": str((PNG_ROOT / final_name).is_file()),
                "MappingStatus": "embedded_hd_manifest",
                "Notes": "TSW ID/SN recovered from the Steam HD embedded manifest.",
            }
        )
    write_csv(
        GALLERY_ROOT / "hd_tsw_png_index.csv",
        inventory_rows,
        ["OriginalPngFile", "PngFile", "TswBindings", "PngExists", "MappingStatus", "Notes"],
    )

    known_rows = [
        {
            "TswId": "9385", "SN": "0", "Status": "embedded_manifest_and_game_verified", "Purpose": "物品頁背景",
            "Evidence": "GameData.ACTdef.MenuWallPaper_BG_TSW；實機繪製確認不透明；HD manifest recovered from package.",
            "MatchingPng": final_names["MenuWallPaper_BG_item.png"],
        },
        {
            "TswId": "10007", "SN": "0", "Status": "embedded_manifest_and_game_verified", "Purpose": "戰鬥 AI 說明底圖",
            "Evidence": "原版 OnEvent_Battle.lua 註解與實機繪製確認半透明藍色；HD manifest recovered from package.",
            "MatchingPng": final_names["BattleInfoBG.png"],
        },
    ]
    write_csv(
        GALLERY_ROOT / "hd_tsw_known_references.csv",
        known_rows,
        ["TswId", "SN", "Status", "Purpose", "Evidence", "MatchingPng"],
    )

    found = sum((PNG_ROOT / name).is_file() for name in final_names.values())
    missing = len(final_names) - found
    if found != EXPECTED_PNG_FILES or missing != EXPECTED_MISSING_ASSETS:
        raise ValueError(
            "HD gallery verification failed: "
            f"found={found}, expected_found={EXPECTED_PNG_FILES}, "
            f"missing={missing}, expected_missing={EXPECTED_MISSING_ASSETS}"
        )
    print(f"Recovered {len(manifest_rows)} TSW rows and {len(final_names)} unique asset names.")
    print(f"Renamed/indexed {found} PNG previews; manifest assets missing from archive extraction={missing}.")


if __name__ == "__main__":
    main()
