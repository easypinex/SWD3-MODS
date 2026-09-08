"""Offline ordered-recipe closure; witnesses end at explicitly scoped shop seeds."""
import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path


def array(obj):
    return [obj[str(i)] for i in range(1, len(obj) + 1)]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--names', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    workspace = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if not out.is_relative_to(workspace / '.work') or out.exists():
        raise ValueError('Use a new directory under workspace .work')
    doc = json.loads(args.data.read_text(encoding='utf-8-sig'))
    items = {int(k): v for k, v in doc['items'].items()}
    names = {}
    for line in args.names.read_text(encoding='utf-8-sig').splitlines():
        key, _, text = line.partition(' ')
        names[key] = text
    def name(i): return names.get(items[i].get('Name'), str(i))
    rev, matrix = array(doc['rev']), array(doc['table'])
    fixed = [array(v) for v in array(doc['xy'])]
    candidates = collections.defaultdict(list)
    for i, v in items.items():
        if (not v.get('IT_06')
                and not v.get('NotInBook') and v.get('Level', 0) > 0):
            candidates[v.get('Race', 0)].append(i)
    cache = {}
    def recipe(a, b):
        if (a,b) in cache: return cache[a,b]
        for x,y,e,w in fixed:
            if (a,b) in ((x,y),(y,x)):
                cache[a,b] = [(e,'east',False),(w,'west',False)]
                return cache[a,b]
        va, vb = items[a], items[b]
        ra, rb = va.get('Race',0), vb.get('Race',0)
        result = []
        for side,ra1,ra2,add,exclude in [('east',ra,rb,6,1),('west',rb,ra,0,2)]:
            race = matrix[rev[ra1]*15+rev[ra2]]
            lv2 = va.get('Level',0)+vb.get('Level',0)+add
            parity = (rb if side=='east' else ra)%2
            pool = []
            for i in candidates[race]:
                v = items[i]
                delta = 2*v['Level']-lv2
                if v.get('Area',0)!=exclude and (delta>=0 if parity==0 else delta<=0):
                    pool.append((abs(delta),i))
            if pool:
                best = min(d for d,i in pool)
                tied = [i for d,i in pool if d==best]
                result += [(i,side,len(tied)>1) for i in tied]
            else:
                result.append((101,side,False))
        cache[a,b] = result
        return result
    # Original Scene.TALK4401/4402: regular Stone Kingdom shops, no one-time flag
    # in these functions. Money, access and native material gating remain conditions.
    seeds = [627,628,626,639,698,697,644,649,657,554,555,568,569,979,995,1031,883]
    valid = {i for i,v in items.items() if 0 <= v.get('Race',0) < len(rev)
             and v.get('Level',0)>0 and not v.get('IT_06') and not v.get('discard')
             and not v.get('isSkill') and not v.get('isUnique')}
    material_races = set(array(doc['refineryTypes']))
    materials = {i for i in valid if items[i].get('Race',0) in material_races}
    assert all(i in items for i in seeds)
    cost = {i: 1 for i in seeds}
    trees = {i: {'id':i,'name':name(i),'shop':'Scene.TALK4401' if i in seeds[:9] else 'Scene.TALK4402'} for i in seeds}
    # Cost is leaf purchases, not money. Strictly improving finite costs prevent
    # a closed cycle without a shop foundation from acquiring renewable status.
    changed = True
    while changed:
        changed = False
        known = [i for i in cost if i in materials]
        for a in known:
            for b in known:  # order is significant to East/West and parity
                for r,side,ambiguous in recipe(a,b):
                    if ambiguous or r not in valid or items[r]['Level']>66:
                        continue
                    n = cost[a]+cost[b]
                    if n < cost.get(r, float('inf')):
                        cost[r]=n
                        trees[r]={'id':r,'name':name(r),'side':side,'a':trees[a],'b':trees[b]}
                        changed=True
    key_targets = [255,179,149,368,178,198,152,154,213,214,632,641,642,646,804,993,1031,979]
    guardians = sorted(i for i,v in items.items() if v.get('IT_12') is True and i not in (438,2203))
    targets = list(dict.fromkeys(key_targets + guardians))
    results = []
    witnesses = set()
    def flatten(tree, bag):
        if 'shop' in tree:
            bag[tree['id']]+=1
        else:
            witnesses.add((tree['a']['id'],tree['b']['id'],tree['side'],tree['id']))
            flatten(tree['a'],bag); flatten(tree['b'],bag)
    for i in targets:
        bag = collections.Counter()
        tree = trees.get(i)
        if tree: flatten(tree,bag)
        results.append({'id':i,'name':name(i),'shop_leaf_count':cost.get(i),
                        'leaves':[{'id':k,'name':name(k),'count':v} for k,v in sorted(bag.items())],
                        'tree':tree,'status':'shop-founded Lua recipe candidate' if tree else 'not proven by this seed set'})
    out.mkdir(parents=True)
    (out/'results.json').write_text(json.dumps({'seeds':seeds,'reachable':len(cost),'targets':results},ensure_ascii=False,indent=2),encoding='utf-8')
    # An independent original-Lua preview check verifies every edge actually used.
    lines = ['return {']+[f'{{{a},{b},"{s}",{r}}},' for a,b,s,r in sorted(witnesses)]+['}']
    (out/'witnesses.lua').write_text('\n'.join(lines),encoding='utf-8')
    evidence_inputs = [args.data,args.names,Path(__file__),Path(__file__).with_name('Export-RefineryData.lua'),
                       Path(__file__).with_name('Verify-RecipeWitnesses.lua')]
    evidence_inputs += [args.names.parent / x for x in ['GameData_ItemData.lua','GameData_BattleCharData.lua',
        'GameData_WeaponData.lua','GameData_ArmorData.lua','GameData_SkillData.lua','GameData_AttackEffect.lua',
        'GameData_RaceDefine.lua','OnEvent_Obsolt.lua','Scene.lua','Function_Repository.lua']]
    manifest = {str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in evidence_inputs}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    attrs = {0:'none',1:'fire',2:'ice',3:'wind',4:'earth',5:'poison',6:'light',7:'dark',8:'thunder',9:'physical',10:'auxiliary'}
    actions = []
    for i in guardians:
        v = items[i]
        entries = [('basic',v.get('AttackEffect',0),None,None)]
        for kind,field,countfield in [('skill','Skills','SkillsCount'),('heal','CR_Skills','CR_SkillsCount'),
                                     ('special','SP_AttackEffects','SP_AttackEffectsCount')]:
            for slot,entry in v.get(field,{}).items():
                entries.append((kind,entry,v.get(countfield,{}).get(slot),slot))
        for kind,entry,count,slot in entries:
            skill = items.get(entry,{}) if kind in ('skill','heal') else {}
            effect_id = skill.get('AttackEffect',0) if skill else entry
            effect = doc['effects'].get(str(effect_id),{})
            actions.append(dict(id=i,name=name(i),kind=kind,entry_id=entry,slot=slot,
                action_name=name(entry) if skill else '',effect_id=effect_id,
                attribute=attrs.get(effect.get('iAttr',0),'unknown'),points=effect.get('iAttackPoint',0),
                wide=effect.get('bWideRange',False),add_hp=skill.get('AddHP',0),
                add_mp=skill.get('AddMP',0),add_sp=skill.get('AddSP',0),initial_count=count,
                summon_sp=v.get('Consumption',0) if v.get('Cons_SP') else None,
                source_hp=v.get('HP',0),source_atk=v.get('ATK',0),source_def=v.get('DEF',0),
                source_spd=v.get('SPD',0),source_wis=v.get('WIS',0),shop_leaf_count=cost.get(i)))
    with (out/'guardian-actions.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(actions[0])); w.writeheader(); w.writerows(actions)
    report=['# 石國商店材料鏈與護駕候選','',
        '原版 HD4.0.5 定義推導；每條列出配方另以原版 Lua 預覽核對。來源只取 Scene.TALK4401／4402。',
        '原版 RefineryType 未列出的材料種族不投入配方；天神種族缺欄按原版 helper 的 0 計。',
        '同級並列結果不採用；有種子才展開，循環本身不構成來源。全鏈成品不超過 Lv66。',
        '這是商店可購、資金足夠、原生允許選材時的備貨候選，不是跨劇情隨時回購或遊戲內成功交易的證明。',
        '葉節點份數只在這組商店種子中求少，不是最省金錢、全遊戲最短配方或完整取得清單。','',
        '| 物品 | 每份商店材料數 | 展開的原料 |','| --- | ---: | --- |']
    for r in results:
        if r['id'] in key_targets:
            report.append('| {}{} | {} | {} |'.format(r['name'],r['id'],r['shop_leaf_count'] or '未證明',
                '、'.join(f"{x['name']}{x['id']}×{x['count']}" for x in r['leaves'])))
    report += ['', '## 所有目標的共同配方邊', '', '| 材料一 | 材料二 | 方向 | 成品 |', '| --- | --- | --- | --- |']
    for a,b,s,r in sorted(witnesses):
        report.append(f'| {name(a)}{a} | {name(b)}{b} | {"東" if s=="east" else "西"} | {name(r)}{r} |')
    (out/'REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
    print('reachable',len(cost),'witness edges',len(witnesses))
    for r in results:
        if r['id'] in key_targets: print(r['id'],r['name'],r['shop_leaf_count'])


if __name__=='__main__': main()
