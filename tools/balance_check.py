import json
base='E:/godot/ai-game-0628/data/'
parts=json.load(open(base+'telescope_parts.json',encoding='utf-8'))
objs={o['id']:o for o in json.load(open(base+'celestial_objects.json',encoding='utf-8'))}
levels=json.load(open(base+'levels.json',encoding='utf-8'))

def best(ptype, lvl):
    cands=[p for p in parts if p['type']==ptype and p['unlock_level']<=lvl]
    return cands[-1] if cands else None

def stats(sel, assembly=100):
    obj_,ep=sel['objective'],sel['eyepiece']
    mag=obj_['focal_length_mm']/ep['focal_length_mm']
    light=min(obj_['aperture_mm']/120*100,100)
    base_st=sel['mount']['stability']*0.65+sel['tripod']['stability_bonus']*0.35
    bq=obj_['quality']*0.4+ep['quality']*0.3+sel['tube']['alignment_quality']*0.2+sel['mount']['stability']*0.1
    clarity=bq*assembly/100
    if mag>obj_['aperture_mm']*2: clarity-=(mag-obj_['aperture_mm']*2)*0.5
    stability=base_st*assembly/100
    return mag,light,max(0,clarity),stability

for lv in levels:
    n=lv['level_number']; t=objs[lv['target_object_id']]
    sel={pt:best(pt,n) for pt in ['tripod','mount','tube','objective','eyepiece']}
    for asm in (100,85,70):
        mag,light,cl,st=stats(sel,asm)
        r=min(light/t['required_light_score'],cl/t['required_clarity'],st/t['required_stability'])
        q='Excellent' if r>=1.3 else 'Good' if r>=1.0 else 'Fair' if r>=0.75 else 'Poor' if r>=0.45 else 'Failed'
        print(f"L{n} {t['id']:<13} asm={asm} light={light:.0f} clar={cl:.0f} stab={st:.0f} ratio={r:.2f} -> {q}")
