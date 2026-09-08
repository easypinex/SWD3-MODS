"""Read-only source-data balance model; neither a game simulator nor a save reader."""
import csv
import hashlib
import json
import math
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'docs/knowledge/original-game-data/battle-balance-and-capture/generated'
SOURCE = ROOT / '.work/extracted/script-index-inspect/out_data/GameData_NewGame.lua'
OUT = Path(__file__).resolve().parent / 'evidence/balance-model-v011-20260908.json'


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def num(value):
    return int(value or 0)


items = {num(r['item_id']): r for r in rows(DATA / 'item-combat-details.csv')}
players = rows(DATA / 'players-level-60.csv')
guardians = {num(r['item_id']): r for r in rows(DATA / 'endgame/guardian-comparison.csv')}
hp_guard_pair = sorted((i for i,g in guardians.items() if g['pool']=='static_mod'
                       and i!=10096 and num(g['source_id'])!=438),
                      key=lambda i:num(guardians[i]['add_hp']), reverse=True)[:2]
hp_guard_bonus = sum(num(guardians[i]['add_hp']) for i in hp_guard_pair)
initial = {}
for role, body in re.findall(r'GameData.NewGameChar\[(\d+)\]\s*=\s*\{(.*?)\}', SOURCE.read_text(encoding='utf-8-sig'), re.S):
    initial[int(role)] = {k: int(v) for k, v in re.findall(r'(Attr\w+)\s*=\s*(-?\d+)', body)}
assert len(initial) == 4

# Slots: weapon/head/chest/hand/foot/accessory1/accessory2.
GEAR = {
    'defence': [[580,898,869,887,912,993,995], [536,1030,1015,889,909,994,993],
                [553,1025,1017,889,1040,995,993], [562,905,871,886,915,979,993]],
    'counter': [[580,898,869,887,912,979,993], [536,1031,1015,889,909,994,993],
                [553,1031,1017,1047,1040,995,993], [562,905,871,886,915,979,993]],
}
ARTIFACTS = {'defence': [[],[],[],[]], 'counter': [[],[948],[],[949]]}
NATIVE_GUARDS = [[255,178],[179,198],[149,152],[368,154]]
SLOTS = ['IT_09','IT_29','IT_31','IT_30','IT_32','IT_11','IT_11']
results = []
for profile in ['defence','counter','individual_max_resistance']:
    for role, player in enumerate(players, 1):
        ids = list(GEAR['defence' if profile == 'defence' else 'counter'][role-1])
        artifacts = list(ARTIFACTS['defence' if profile == 'defence' else 'counter'][role-1])
        if profile == 'individual_max_resistance':
            ids[2] = 1018
            artifacts = [948,949]
        assert len(set(ids)) == 7 and len(artifacts) <= 2
        for ident, slot in zip(ids, SLOTS):
            item = items[ident]
            assert str(role) in item['roles'].split('|'), (role, ident)
            assert slot in item['types'].split('|') and 'IT_07' not in item['types'].split('|')
            assert not item['discard']
        for ident in artifacts:
            assert 'IT_07' in items[ident]['types'].split('|')
            assert str(role) in items[ident]['roles'].split('|')
        guard_ids = NATIVE_GUARDS[role-1]
        assert all(str(role) in items[i]['roles'].split('|') for i in guard_ids)
        source_hp = num(player['hp']) + sum(num(items[i]['AddHP']) for i in ids)
        source_hp += sum(num(guardians[i]['add_hp']) for i in guard_ids)
        # Source arithmetic only: no invented STR->ATK or Stamina->DEF formula.
        additions = {k: sum(num(items[i][k]) for i in ids) for k in ['AddATK','AddDEF','AddSPD','AddMP','AddSP']}
        hp_mod_pair_upper = num(player['hp']) + sum(num(items[i]['AddHP']) for i in ids)
        hp_mod_pair_upper += hp_guard_bonus  # two distinct cards, per-person boundary only
        entry = dict(profile=profile, role=role, name=player['name'], gear=ids,
                     gear_names=[items[i]['name'] for i in ids], artifacts=artifacts,
                     artifact_names=[items[i]['name'] for i in artifacts], guardians=guard_ids,
                     source_hp=source_hp, growth_N1_hp=source_hp+1000,
                     mod_pair_hp_boundary=hp_mod_pair_upper, source_additions=additions, effects={})
        for attr, points, spell in [('AttrLight',3000,'light_single'),('AttrDark',3200,'dark_area'),
                                    ('AttrDark',4800,'dark_ultimate')]:
            components = [initial[role].get(attr,0)] + [num(items[i][attr]) for i in ids+artifacts]
            # Alternative assumptions, NOT proven engine formulas or statistical confidence bounds.
            # Negative additive results are classified as immunity/absorption boundary; no heal forecast.
            additive = max(0,1+sum(components)/10)
            multiplicative = math.prod(max(0,1+c/10) for c in components)
            entry['effects'][spell] = dict(points=points, components=components,
                raw_attr_sum=sum(components), additive_factor=round(additive,6),
                multiplicative_factor=round(multiplicative,6),
                additive_index=round(points*additive,1), multiplicative_index=round(points*multiplicative,1))
        results.append(entry)

inputs = [SOURCE, DATA/'item-combat-details.csv', DATA/'players-level-60.csv',
          DATA/'endgame/guardian-comparison.csv', Path(__file__)]
report = dict(
    model='definition-based sensitivity model; indices are NOT predicted HP damage',
    assumptions=['Lv60 four heroes; native guardian pairs listed once each; no Cai benefit',
                 'defence leaves artifact resistance out as comparison, not a recommended empty loadout',
                 'counter uses one light tower and one dark vessel across the team; listed equipment assumed acquired',
                 'max resistance is an individual boundary, not four simultaneous copies of each rare artifact',
                 'artifact resistance evaluated at full training as definition ceiling',
                 'no WIS, defence, random, guard or critical multiplier invented',
                 'growth N1 adds HP1000; highest HP pair of two distinct mod cards is a per-person boundary only'],
    highest_hp_distinct_mod_pair={'ids':hp_guard_pair,'hp_bonus':hp_guard_bonus},
    provenance={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
    loadouts=results,
    durability={'initial_hp':80000,'one_heal':6000,'total_max':86000,
                'heal_fraction_of_initial':0.075,
                'required_actual_damage_per_four_hero_action_window':{'6_windows':14333.33,'8_windows':10750,'10_windows':8600}},
    phase_two_selection_cycle=[11004,11003,0,11002],
    counter_team_dark_index={mode:round(sum(r['effects']['dark_area'][mode] for r in results
        if r['profile']=='counter'),1) for mode in ['additive_index','multiplicative_index']},
    area_healing={'true_dream_doll_804':{'hp_each':4000,'sp_cost':300,'max_four_hero_hp':16000}},
)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for r in results:
    light=r['effects']['light_single']; dark=r['effects']['dark_area']
    print(f"{r['profile']:25} {r['name']} HP={r['source_hp']} "
          f"light A/B={light['additive_index']}/{light['multiplicative_index']} "
          f"dark A/B={dark['additive_index']}/{dark['multiplicative_index']}")
print('PASS: four legal roles, seven distinct equipment slots, guardian eligibility and source fingerprints')
