import cv2,numpy as np,json,heapq,sys
from seg import *
L=194.0; W=107.6
def unit(v): v=np.array(v,float); return v/np.linalg.norm(v)
def automap(pg,entry_mid,entry_dir,exit_mid,exit_dir,name):
    a=load(pg); lab,cs=cells(a); bd=boundaries(a,lab,cs,r=18)
    # scarta le zone fuori pista: molto grandi o di forma irregolare e senza confini blu
    med=np.median([cs[i]['area'] for i in cs])
    blue_any={i:False for i in cs}
    for (i,j),b in bd.items():
        if 100<=b['h']<=126 and b['s']>=35: blue_any[i]=blue_any[j]=True
    for i in list(cs):
        if not blue_any[i] and ((cs[i]['area']>2.6*med and cs[i]['fill']<0.45) or cs[i]['fill']<0.35):
            del cs[i]
    bd={k:v for k,v in bd.items() if k[0] in cs and k[1] in cs}
    ids=sorted(cs); C={i:cs[i]['c'] for i in ids}
    em=np.array(entry_mid,float); ed=unit(entry_dir); xm=np.array(exit_mid,float); xd=unit(exit_dir)
    # tipo di confine
    kind={}; doubt_b=[]
    for (i,j),b in bd.items():
        # un confine lungo più di una larghezza di corsia è una linea di corsia (nera)
        if b['len']>165: kind[(i,j)]='black'; continue
        blue = 100<=b['h']<=126 and b['s']>=35
        black = (b['h']<90 or b['s']<30) and b['v']<30
        if blue and not black: kind[(i,j)]='blue'
        elif black and not blue: kind[(i,j)]='black'
        else: kind[(i,j)]='blue' if b['h']>=95 else 'black'; doubt_b.append((i,j))
    # celle di ingresso: vicine alla linea d'ingresso, dalla parte interna
    ent=[i for i in ids if 0 < (C[i]-em)@ed < 0.8*L and abs((C[i]-em)@np.array([ed[1],-ed[0]]))<3.2*W]
    ext=[i for i in ids if 0 < (xm-C[i])@xd < 0.8*L]
    # progresso: cammino minimo dall'ingresso su tutte le adiacenze
    adj={i:[] for i in ids}
    for (i,j) in bd:
        d=float(np.linalg.norm(C[i]-C[j])); adj[i].append((j,d)); adj[j].append((i,d))
    prog={i:1e9 for i in ids}; pq=[]
    for i in ent:
        prog[i]=float((C[i]-em)@ed); heapq.heappush(pq,(prog[i],i))
    while pq:
        d,i=heapq.heappop(pq)
        if d>prog[i]: continue
        for j,w in adj[i]:
            # i passi laterali (linea nera) pesano meno, così non gonfiano il progresso
            ww=w if kind.get((min(i,j),max(i,j)))=='blue' else w*0.15
            if d+ww<prog[j]: prog[j]=d+ww; heapq.heappush(pq,(prog[j],j))
    links=[]; doubt_l=[]
    for (i,j),k in kind.items():
        if k!='blue': continue
        if prog[i]>=1e9 or prog[j]>=1e9: doubt_l.append((i,j)); continue
        a_,b_=(i,j) if prog[i]<prog[j] else (j,i)
        if abs(prog[i]-prog[j])<0.05*L: doubt_l.append((a_,b_))
        links.append((a_,b_))
    outs={i:0 for i in ids}; ins={i:0 for i in ids}
    for a_,b_ in links: outs[a_]+=1; ins[b_]+=1
    doubt_c=[]
    med=np.median([cs[i]['area'] for i in ids])
    for i in ids:
        why=[]
        if prog[i]>=1e9: why.append('non collegata')
        if ins[i]==0 and i not in ent: why.append('nessuna casella dietro')
        if outs[i]==0 and i not in ext: why.append('nessuna casella davanti')
        if outs[i]>1: why.append('due caselle davanti')
        if cs[i]['area']>2.2*med: why.append('molto grande')
        if cs[i]['fill']<0.4: why.append('forma strana')
        if why: doubt_c.append((i,why))
    return dict(a=a,lab=lab,cs=cs,C=C,links=links,kind=kind,ent=ent,ext=ext,prog=prog,doubt_c=doubt_c,doubt_l=doubt_l,doubt_b=doubt_b,ids=ids)
def draw(r,fn,scale=0.5):
    a=r['a'].copy(); lab=r['lab']
    ov=a.copy()
    dc={i for i,_ in r['doubt_c']}
    for i in r['ids']:
        ov[lab==i]=(60,200,255) if i in dc else (120,220,120)
    a=cv2.addWeighted(a,0.55,ov,0.45,0)
    C=r['C']
    for (i,j),k in r['kind'].items():
        if k=='black': cv2.line(a,tuple(C[i].astype(int)),tuple(C[j].astype(int)),(80,80,80),2)
    dl=set(r['doubt_l'])
    for a_,b_ in r['links']:
        col=(0,0,255) if (a_,b_) in dl else (200,90,0)
        cv2.arrowedLine(a,tuple(C[a_].astype(int)),tuple(C[b_].astype(int)),col,5,tipLength=0.25)
    num={i:k+1 for k,i in enumerate(r['ids'])}
    for i in r['ids']:
        p=tuple((C[i]+np.array([-18,14])).astype(int))
        cv2.putText(a,str(num[i]),p,0,1.2,(255,255,255),6);cv2.putText(a,str(num[i]),p,0,1.2,(0,0,0) if i not in dc else (0,0,200),3)
    cv2.imwrite(fn,cv2.resize(a,(int(a.shape[1]*scale),int(a.shape[0]*scale))))
    return num
if __name__=='__main__':
    r=automap(7,(361,1562.5),(425,-400),(689.5,0),(0,-1),'p07')
    num=draw(r,'p07.jpg')
    print('celle',len(r['ids']),'avanti',len(r['links']),'ingresso',len(r['ent']),'uscita',len(r['ext']))
    for i,w in r['doubt_c']: print(' dubbia',num[i],w)
    print(' collegamenti dubbi',[(num[a],num[b]) for a,b in r['doubt_l']],'confini dubbi',[(num[a],num[b]) for a,b in r['doubt_b']])
