import cv2,numpy as np,json
from automap import automap
from run4 import FACES
import builtins
for fid,(pg,em,ed,xm,xd) in FACES.items():
    r=automap(pg,em,ed,xm,xd,fid)
    # scarta macchie fuori pista: nessun confine blu e non all'ingresso
    blue_nb={i:0 for i in r['ids']}
    for (i,j),k in r['kind'].items():
        if k=='blue': blue_nb[i]+=1; blue_nb[j]+=1
    keep=[i for i in r['ids'] if blue_nb[i]>0 or i in r['ent']]
    face=json.load(open(f'/tmp/proj/data/faces/{fid}.json'))
    fm=face['entry']['mid']; x0=em[0]-fm[0]*2; y0=em[1]-fm[1]*2
    idx={i:k for k,i in enumerate(keep)}
    cells=[[round((r['C'][i][0]-x0)*0.5,1),round((r['C'][i][1]-y0)*0.5,1)] for i in keep]
    links=[[idx[a],idx[b]] for a,b in r['links'] if a in idx and b in idx]
    dl=set(r['doubt_l'])
    outs={k:0 for k in range(len(keep))}; ins={k:0 for k in range(len(keep))}
    for a,b in links: outs[a]+=1; ins[b]+=1
    ent={idx[i] for i in r['ent'] if i in idx}; ext={idx[i] for i in r['ext'] if i in idx}
    doubts=[]
    for k,i in enumerate(keep):
        why=[]
        if ins[k]==0 and k not in ent: why.append('inizia qui: nessuna casella dietro')
        if outs[k]==0 and k not in ext: why.append('finisce qui: nessuna casella davanti')
        if outs[k]>1: why.append('due caselle davanti')
        if any(a==i and (a,b) in dl for a,b in r['links']): why.append('verso incerto')
        if why: doubts.append({'cell':k,'why':why})
    face['cells']=cells; face['links']=links; face['doubts']=doubts; face['auto']=True; face['mapped']=True
    face.pop('lanes',None)
    json.dump(face,open(f'/tmp/proj/data/faces/{fid}.json','w'),ensure_ascii=False,indent=1)
    # immagine per l'utente: numeri sulle caselle dubbie
    img=cv2.imread(f'/tmp/proj/assets/tiles/{fid}.webp',cv2.IMREAD_UNCHANGED)
    isc=face.get('img_scale',1.0)
    img=cv2.resize(img,(int(img.shape[1]/isc),int(img.shape[0]/isc)),interpolation=cv2.INTER_AREA)
    bg=np.full(img.shape[:2]+(3,),255,np.uint8);al=img[:,:,3:]/255.;v=(img[:,:,:3]*al+bg*(1-al)).astype(np.uint8)
    v=cv2.addWeighted(v,0.7,np.full_like(v,255),0.3,0)
    for a,b in links:
        p=tuple(int(t) for t in cells[a]);q=tuple(int(t) for t in cells[b]);cv2.arrowedLine(v,p,q,(160,110,20),2,tipLength=0.3)
    dset={d['cell'] for d in doubts}
    for k,c in enumerate(cells):
        p=(int(c[0]),int(c[1]))
        if k in dset:
            cv2.circle(v,p,15,(0,140,255),-1);cv2.putText(v,str(k),(p[0]-11 if k>9 else p[0]-6,p[1]+6),0,0.5,(255,255,255),2)
        else:
            cv2.circle(v,p,5,(60,60,60),-1)
    m=face['entry']['mid'];d=face['entry']['dir'];cv2.arrowedLine(v,(int(m[0]),int(m[1])),(int(m[0]+d[0]*60),int(m[1]+d[1]*60)),(0,170,0),4)
    m=face['exit']['mid'];d=face['exit']['dir'];cv2.arrowedLine(v,(int(m[0]),int(m[1])),(int(m[0]+d[0]*60),int(m[1]+d[1]*60)),(0,0,220),4)
    cv2.imwrite(f'/tmp/auto/dubbi_{fid}.png',v)
    print(fid,len(cells),'caselle',len(links),'collegamenti',len(doubts),'dubbie')
    for d in doubts: print('   ',d['cell'],'; '.join(d['why']))
