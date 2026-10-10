# Incorpora le correzioni dell'utente (tools/corrections/*.json) nelle facce di base.
# Va eseguito dopo ogni rigenerazione delle facce, così le correzioni non si perdono.
import json,glob,os,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for f in sorted(glob.glob(os.path.join(ROOT,'tools','corrections','*.json'))):
    u=json.load(open(f)); fid=u['id']
    bp=os.path.join(ROOT,'data','faces',fid+'.json')
    b=json.load(open(bp))
    ref=u.get('ref_entry') or u['entry']['mid']
    dx=b['entry']['mid'][0]-ref[0]; dy=b['entry']['mid'][1]-ref[1]
    b['cells']=[[round(c[0]+dx,1),round(c[1]+dy,1)] for c in u['cells']]
    b['links']=u['links']
    for k in ('drift_add','drift_remove'):
        if k in u: b[k]=u[k]
    for k in ('doubts','lanes'): b.pop(k,None)
    b['auto']=False; b['verified']=True; b['mapped']=True
    json.dump(b,open(bp,'w'),ensure_ascii=False,indent=1)
    print(fid,len(b['cells']),'caselle',len(b['links']),'collegamenti, spostamento',(round(dx,1),round(dy,1)))
