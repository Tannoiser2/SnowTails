# Rete delle inversioni dalle "strisce": le linee spesse separano le strisce di caselle
# (le linee sottili/tratteggiate dividono le caselle). Dentro una striscia si avanza di casella
# in casella; dove una striscia finisce si passa alla casella che sta davanti.
import cv2,numpy as np,json,math
from scipy import ndimage as ndi
from run4 import FACES as F4
CFG={'uturn_R_p02':dict(page=2,entry_top=True),'uturn_L_p01':dict(page=1,entry_top=False)}
W=53.8
def build(fid):
    cfg=CFG[fid]; a=cv2.imread('/tmp/p200/p-%02d.png'%cfg['page']); g=cv2.cvtColor(a,cv2.COLOR_BGR2GRAY)
    d=(g<130).astype(np.uint8); thick=cv2.morphologyEx(d,cv2.MORPH_OPEN,np.ones((2,2),np.uint8))
    L=cv2.dilate(thick,np.ones((5,5),np.uint8))>0
    lab,n=ndi.label(~L)
    face=json.load(open(f'/tmp/proj/data/faces/{fid}.json'))
    em=F4[fid][1]; fm=face['entry']['mid']; x0=em[0]-fm[0]*2; y0=em[1]-fm[1]*2
    cells=[np.array(c,float) for c in face['cells']]
    def strip_of(c):
        x=int(round(c[0]*2+x0)); y=int(round(c[1]*2+y0))
        for r in range(0,30,2):
            win=lab[max(0,y-r):y+r+1,max(0,x-r):x+r+1]
            vals=[v for v in np.unique(win) if v>0]
            if vals:
                # la più frequente nella finestra
                cnt=[(int((win==v).sum()),v) for v in vals]; return max(cnt)[1]
        return -1
    st=[strip_of(c) for c in cells]
    # parametro di marcia lungo la U
    ent=np.array(face['entry']['mid'],float); ext=np.array(face['exit']['mid'],float)
    ymid=(ent[1]+ext[1])/2; r_in=abs(ymid-ent[1])-2.5*W
    tipx=min(c[0] for c in cells if abs(c[1]-ymid)<W*0.6) - W*0.5
    C=np.array([tipx-r_in,ymid])
    def tpar(c):
        if c[0]<C[0]:
            top=c[1]<ymid; entry_half= top if cfg['entry_top'] else not top
            return -10000+c[0] if entry_half else 10000-c[0]
        ang=math.degrees(math.atan2(c[1]-C[1],c[0]-C[0]))
        return ang if cfg['entry_top'] else -ang
    T=[tpar(c) for c in cells]
    groups={}
    for i,s in enumerate(st): groups.setdefault(s,[]).append(i)
    links=[]
    for s,ids in groups.items():
        seq=sorted(ids,key=lambda i:T[i])
        for u,v in zip(seq,seq[1:]): links.append([u,v])
    # fine striscia: casella davanti
    outs={i:0 for i in range(len(cells))}; ins={i:0 for i in range(len(cells))}
    for u,v in links: outs[u]+=1; ins[v]+=1
    exit_dir=np.array(face['exit']['dir'],float)
    for i,c in enumerate(cells):
        if outs[i]>0: continue
        if np.dot(ext-c,exit_dir)<W*1.2 and abs(np.dot(c-ext,np.array([exit_dir[1],-exit_dir[0]])))<W*3: continue   # sul bordo d'uscita
        # direzione locale: dalla casella precedente della striscia, o dal parametro
        prev=[u for u,v in links if v==i]
        if prev: f=(c-cells[prev[0]]); f/=np.linalg.norm(f)
        else: continue
        best=None
        for j,o in enumerate(cells):
            if j==i or st[j]==st[i]: continue
            dv=o-c; along=float(np.dot(dv,f)); lat=abs(float(dv[0]*f[1]-dv[1]*f[0]))
            if along<W*0.3 or along>W*3.2 or lat>W*0.75: continue
            sc=along+lat*2
            if best is None or sc<best[0]: best=(sc,j)
        if best: links.append([i,best[1]])
    return face,links,st,T
if __name__=='__main__':
    res={}
    for fid in CFG:
        face,links,st,T=build(fid)
        res[fid]=links
        img=cv2.imread(f'/tmp/proj/assets/tiles/{fid}.webp',cv2.IMREAD_UNCHANGED);k=1/face['img_scale']
        img=cv2.resize(img,(int(img.shape[1]*k),int(img.shape[0]*k)))
        bg=np.full(img.shape[:2]+(3,),255,np.uint8);al=img[:,:,3:]/255.;v=(img[:,:,:3]*al+bg*(1-al)).astype(np.uint8)
        S=1.2;v=cv2.resize(v,None,fx=S,fy=S);v=cv2.addWeighted(v,0.6,np.full_like(v,255),0.4,0)
        P=lambda c:(int(c[0]*S),int(c[1]*S))
        rng=np.random.RandomState(3);cols={s:tuple(int(x) for x in rng.randint(0,200,3)) for s in set(st)}
        for u,w in links: cv2.arrowedLine(v,P(face['cells'][u]),P(face['cells'][w]),cols[st[u]],3,tipLength=0.25)
        for i,c in enumerate(face['cells']):
            cv2.circle(v,P(c),9,(255,255,255),-1);cv2.putText(v,str(i),(P(c)[0]-9,P(c)[1]+5),0,0.42,(0,0,200),1)
        cv2.imwrite(f'/tmp/auto/strips_{fid}.png',v)
        print(fid,len(links),'collegamenti, strisce',len(set(st)),'non in striscia',st.count(-1))
    json.dump(res,open('/tmp/auto/uturn_strip_links.json','w'))
