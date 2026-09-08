"""Reproducible definition rankings and literal acquisition leads; no game execution."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def number(value):
    return int(value or 0)


def write_csv(root, name, rows, fields):
    with (root / name).open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def mask_lua(text):
    """Blank comments and strings, preserving offsets for literal-call indexing."""
    pattern = r"--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|\[(=*)\[[\s\S]*?\]\2\]"
    return re.sub(pattern, lambda m: re.sub(r"[^\n]", " ", m[0]), text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--static-cards", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    output = args.output_root.resolve()
    workspace = Path(__file__).resolve().parents[4]
    if not output.is_relative_to(workspace) or output.exists():
        raise ValueError("Output must be a new directory inside the workspace")
    source = args.source_root.resolve()
    data = args.data_root.resolve()
    if output.is_relative_to(source) or output.is_relative_to(data):
        raise ValueError("Output cannot be inside an input directory")
    inputs = sorted(data.glob("*.csv")) + sorted(source.glob("*.lua"))
    inputs += [source / "ItemString.txt", args.static_cards.resolve(), Path(__file__).resolve(),
               Path(__file__).with_name("Extract-OriginalBalanceData.lua").resolve(),
               Path(__file__).with_name("Build-OriginalBalanceData.ps1").resolve()]
    fingerprints = {str(p.relative_to(workspace)) if p.is_relative_to(workspace) else str(p):
                    hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    details = {r["item_id"]: r for r in read_csv(data / "item-combat-details.csv")}
    equipment = read_csv(data / "equipment-and-artifacts.csv")
    guardians = read_csv(data / "guardian-cards.csv")
    mod_cards = read_csv(args.static_cards)
    combatants = {r["item_id"]: r for r in read_csv(data / "combatants.csv")}
    skills = {r["item_id"]: r for r in read_csv(data / "skills.csv")}
    effects = {r["effect_id"]: r for r in read_csv(data / "attack-effects.csv")}
    output.mkdir(parents=True)

    # Each row is a per-stat candidate, not a globally optimal or attainable build.
    candidates = []
    slots = {"weapon": "IT_09", "head": "IT_29", "chest": "IT_31",
             "hand": "IT_30", "foot": "IT_32", "accessory": "IT_11"}
    for role in range(1, 5):
        for slot, flag in slots.items():
            eligible = [r for r in equipment if flag in r["slot_types"].split("|")
                        and str(role) in r["roles"].split("|") and r["discard"] != "Y"
                        and "IT_07" not in r["slot_types"].split("|")]
            for stat in ("add_atk", "add_def", "add_spd", "add_hp", "add_mp"):
                ranked = sorted(eligible, key=lambda r: (-number(r[stat]), number(r["item_id"])))
                for rank, row in enumerate(ranked[:3], 1):
                    if number(row[stat]) <= 0:
                        continue
                    detail = details[row["item_id"]]
                    candidates.append(dict(role=role, slot=slot, metric=stat, rank=rank,
                        item_id=row["item_id"], name=row["name"], value=row[stat],
                        proficient_point=detail["ProficientPoint"],
                        proficient_hard=detail["ProficientHard"], special=detail["AddSpecial"],
                        acquisition="candidate; availability and shared inventory not solved"))
    write_csv(output, "equipment-candidates.csv", candidates,
              ["role", "slot", "metric", "rank", "item_id", "name", "value",
               "proficient_point", "proficient_hard", "special", "acquisition"])

    # Preserve native and MOD pools separately; exclude Cai source 438 and card 10096.
    guard_rows = []
    add_fields = {"hp": "AddHP", "mp": "AddMP", "sp": "AddSP", "str": "AddSTR",
                  "stamina": "AddStamina", "wis": "AddWIS", "spd": "AddSPD",
                  "atk": "AddATK", "def": "AddDEF"}
    for row in guardians:
        if row["item_id"] == "438":
            continue
        detail = details[row["item_id"]]
        guard_rows.append(dict(pool="native", item_id=row["item_id"], name=row["name"],
            availability_note="original comment: test only" if row["item_id"] == "2203" else "acquisition not guaranteed",
            source_id=row["item_id"], sp_cost=row["sp_cost"],
            **{"add_" + key: detail[field] for key, field in add_fields.items()},
            **{key: row["combatant_" + key] for key in ("hp", "atk", "def", "spd", "wis")}))
    for row in mod_cards:
        if row["source_enemy_id"] == "438":
            continue
        guard_rows.append(dict(pool="static_mod", item_id=row["card_id"], name=row["card_name"],
            availability_note="requires static capture MOD; runtime summoning still case-dependent",
            source_id=row["source_enemy_id"], sp_cost=row["guardian_sp_cost"],
            **{"add_" + key: row["add_" + key] for key in add_fields},
            **{key: row["card_battle_" + key] for key in ("hp", "atk", "def")},
            spd=row["source_spd"], wis=row["source_wis"]))
    write_csv(output, "guardian-comparison.csv", guard_rows, list(guard_rows[0]))

    # Join offensive, healing and resource-denial fields. Repeated slots remain
    # separate: duplicate cure entries are separate weighted AI choices.
    pressure_rows = []
    for index, action in enumerate(read_csv(data / "current-challengeable-enemy-actions.csv"), 1):
        is_skill = action["action_type"] in ("技能", "治療／危急技能")
        skill = skills.get(action["source_id"]) if is_skill else None
        detail = details.get(action["source_id"], {}) if skill is not None else {}
        effect = effects.get(action["attack_effect_id"], {})
        tags = []
        for field, label in (("snatch_hp", "HP_drain"), ("snatch_mp", "MP_drain"), ("snatch_sp", "SP_drain")):
            if effect.get(field) == "Y":
                tags.append(label)
        if number(detail.get("AddHP")) > 0:
            tags.append("HP_recovery_definition")
        if effect.get("wide_range") == "Y":
            tags.append("area_effect")
        if number(effect.get("affixation_effect")):
            tags.append("status_effect")
        if is_skill and skill is None:
            tags.append("missing_skill_definition")
        if not effect:
            tags.append("missing_effect_definition")
        pressure_rows.append(dict(action_row=index, enemy_id=action["enemy_id"], enemy_name=action["enemy_name"],
            action_type=action["action_type"], source_id=action["source_id"], action_name=action["action_name"],
            effect_id=action["attack_effect_id"], attack_point=action["attack_point"],
            attribute_id=action["attribute_id"], wide_range=action["wide_range"],
            add_hp=detail.get("AddHP", ""), add_mp=detail.get("AddMP", ""), add_sp=detail.get("AddSP", ""),
            calculation=detail.get("Calculation", ""),
            snatch_hp=effect.get("snatch_hp", ""), snatch_mp=effect.get("snatch_mp", ""), snatch_sp=effect.get("snatch_sp", ""),
            affixation_effect=action["affixation_effect"], relieve_effect=effect.get("relieve_effect", ""),
            add_buff=action["add_buff"], continuous_turns=action["continuous_turns"],
            initial_usage_count=action["initial_usage_count"], ai_rate=action["ai_rate"],
            risk_tags="|".join(tags),
            targeting="lowest absolute current HP living enemy; effect range may expand" if action["action_type"] == "治療／危急技能" else "player target or initialization self flag; runtime target set not proven",
            limitation="definition only; damage/heal totals, successful targets and timings need runtime verification"))
    write_csv(output, "enemy-action-pressure.csv", pressure_rows, list(pressure_rows[0]))

    # Deliberately narrow literal-call recognizer: not a Lua interpreter or reachability proof.
    refs = []
    calls = re.compile(r"\b(ESC\.OpenStore|Scene\.OpenChest|ItemFunc\.AddItem)\s*\(([^()]*)\)", re.S)
    for file in sorted(source.glob("*.lua")):
        raw = file.read_text(encoding="utf-8-sig")
        code = mask_lua(raw)
        symbols = list(re.finditer(r"\bfunction\s+([\w.:]+)\s*\(", code))
        for match in calls.finditer(code):
            call, arguments = match.groups()
            parts = [part.strip() for part in arguments.split(",")]
            found = []
            if call == "ESC.OpenStore" and all(re.fullmatch(r"\d+", p) for p in parts):
                found = [(p, "", "store_listing") for p in parts if p != "0"]
            elif call == "Scene.OpenChest" and len(parts) >= 2 and re.fullmatch(r"\d+", parts[1]):
                found = [(parts[1], "", "chest_reference")]
            elif call == "ItemFunc.AddItem" and len(parts) >= 2 and re.fullmatch(r"\d+", parts[0]) and re.fullmatch(r"-?\d+", parts[1]):
                found = [(parts[0], parts[1], "add_item" if int(parts[1]) > 0 else "remove_item")]
            symbol = next((s[1] for s in reversed(symbols) if s.start() < match.start()), "")
            for item_id, count, kind in found:
                if item_id not in details:
                    continue
                refs.append(dict(item_id=item_id, name=details[item_id]["name"], kind=kind,
                    source_file=file.name, line=raw.count("\n", 0, match.start()) + 1,
                    symbol=symbol, quantity=count, enemy_id="", drop_rate="",
                    limitation="literal reference only; conditions, repeatability and total supply unresolved"))
        # GetItem's second argument commonly contains StringDB(...); index only
        # its literal first argument so nested expressions cannot hide the lead.
        for match in re.finditer(r"\bScene\.GetItem\s*\(\s*(\d+)\s*[,)]", code):
            item_id = match[1]
            if item_id not in details:
                continue
            symbol = next((s[1] for s in reversed(symbols) if s.start() < match.start()), "")
            refs.append(dict(item_id=item_id, name=details[item_id]["name"], kind="get_item_reference",
                source_file=file.name, line=raw.count("\n", 0, match.start()) + 1,
                symbol=symbol, quantity="", enemy_id="", drop_rate="",
                limitation="literal reference only; conditions and quantity unresolved"))
    for enemy in combatants.values():
        ids, rates = enemy["drop_item_ids"].split("|"), enemy["drop_item_rates"].split("|")
        for index, item_id in enumerate(ids):
            if item_id in details:
                refs.append(dict(item_id=item_id, name=details[item_id]["name"], kind="enemy_drop_definition",
                    source_file="GameData_BattleCharData.lua", line="", symbol="ItemTemp[" + enemy["item_id"] + "]",
                    quantity="", enemy_id=enemy["item_id"], drop_rate=rates[index] if index < len(rates) else "",
                    limitation="drop definition; encounter availability and repeatability unresolved"))
    write_csv(output, "item-source-references.csv", refs,
              ["item_id", "name", "kind", "source_file", "line", "symbol", "quantity", "enemy_id", "drop_rate", "limitation"])

    checks = {
        "roles": sorted({r["role"] for r in candidates}),
        "native_guardians": sum(r["pool"] == "native" for r in guard_rows),
        "mod_guardians_without_cai": sum(r["pool"] == "static_mod" for r in guard_rows),
        "special_skill_rows": len(read_csv(data / "player-special-skills.csv")),
        "enemy_action_rows": len(pressure_rows),
        "wide_effect_actions": sum(r["wide_range"] == "Y" for r in pressure_rows),
        "cure_entries": sum(r["action_type"] == "治療／危急技能" for r in pressure_rows),
        "cure_entries_missing_skill": sum(r["action_type"] == "治療／危急技能" and "missing_skill_definition" in r["risk_tags"] for r in pressure_rows),
        "shop_4848_growth_ids": sorted({int(r["item_id"]) for r in refs
            if r["symbol"] == "Scene.TALK4848" and r["kind"] == "store_listing"}),
    }
    assert checks["roles"] == [1, 2, 3, 4]
    assert checks["native_guardians"] == 97 and checks["mod_guardians_without_cai"] == 96
    assert checks["special_skill_rows"] == 12
    assert 688 in checks["shop_4848_growth_ids"] and 695 not in checks["shop_4848_growth_ids"]
    assert not any(r["source_id"] == "438" for r in guard_rows)
    assert any(r["item_id"] == "672" and r["kind"] == "remove_item" for r in refs)
    assert any(r["item_id"] == "553" and r["kind"] == "get_item_reference" and r["symbol"] == "Scene.TALK4834" for r in refs)
    bull_drain = [r for r in pressure_rows if r["enemy_id"] == "59" and r["source_id"] == "1719"]
    assert len(bull_drain) == 1 and bull_drain[0]["wide_range"] == "Y" and bull_drain[0]["snatch_hp"] == "Y"
    assert sum(r["enemy_id"] == "46" and r["add_hp"] == "9999" for r in pressure_rows) == 2
    for p in inputs:
        key = str(p.relative_to(workspace)) if p.is_relative_to(workspace) else str(p)
        assert hashlib.sha256(p.read_bytes()).hexdigest() == fingerprints[key], f"Input changed: {p}"
    manifest = dict(evidence="official definitions + deterministic ranking; no runtime victory claim",
                    inputs_sha256=fingerprints, checks=checks,
                    outputs_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob("*.csv"))})
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(dict(status="PASS", checks=checks, equipment_rows=len(candidates), reference_rows=len(refs)), ensure_ascii=False))


if __name__ == "__main__":
    main()
