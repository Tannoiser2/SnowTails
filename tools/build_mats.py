# Estrae le plance delle slitte (pp.23-24) e carte/gettoni freno dalla foto dell'utente.
import cv2,numpy as np,json,sys
sys.path.insert(0,'/tmp/b')
from scipy import ndimage as ndi
from mask2 import tile_mask2
OUT='/tmp/proj/assets'
S=0.6   # 200 dpi -> 120 dpi per le plance
def rot_cw(img): return cv2.rotate(img,cv2.ROTATE_90_CLOCKWISE)
meta={}
spec={23:['red','green','yellow'],24:['blue','black']}
for pg,cols in spec.items():
    a=cv2.imread(f'/tmp/p200/p-{pg:02d}.png'); m=tile_mask2(a)
    splits=[0,731,1478,2337]
    for k,col in enumerate(cols):
        y0,y1=splits[k],splits[k+1]
        mm=m.copy(); mm[:y0]=False; mm[y1:]=False
        lab,n=ndi.label(mm); sz=ndi.sum(mm,lab,range(1,n+1)); mm=lab==(1+int(np.argmax(sz)))
        mm=ndi.binary_fill_holes(mm)
        ys,xs=np.nonzero(mm); bx0,by0,bx1,by1=xs.min(),ys.min(),xs.max()+1,ys.max()+1
        crop=a[by0:by1,bx0:bx1].copy(); cm=mm[by0:by1,bx0:bx1].copy()
        # foro del freno: bianco puro racchiuso nella metà destra
        white=ndi.binary_opening(crop.min(axis=2)>=253,iterations=3)
        wl,wn=ndi.label(white); best=None
        for i in range(1,wn+1):
            r=wl==i; yy,xx=np.nonzero(r)
            if xx.min()==0 or yy.min()==0 or xx.max()==r.shape[1]-1 or yy.max()==r.shape[0]-1: continue
            if r.sum()<8000 or r.sum()>60000 or xx.mean()<crop.shape[1]*0.6: continue
            if best is None or r.sum()>best[0]: best=(r.sum(),xx.min(),yy.min(),xx.max()+1,yy.max()+1)
        if best is None:
            print('foro non trovato per',col,'- uso la posizione standard'); best=(0,980,253,1103,487)
        _,hx0,hy0,hx1,hy1=best
        cm[hy0:hy1,hx0:hx1]&=~white[hy0:hy1,hx0:hx1]
        # caselle delle carte: relative al foro (misurate sulla prima plancia)
        # caselle delle carte: stessa fustella per tutte le plance, misurate dal bordo
        c1=(27,24,527,353)     # cane in alto nella scansione = cane destro (bandierina rossa)
        c2=(27,387,527,720)    # cane in basso = cane sinistro (bandierina gialla)
        rgba=np.dstack([crop,(cm*255).astype(np.uint8)])
        h,w=rgba.shape[:2]
        rgba=rot_cw(rgba); H,W=rgba.shape[:2]   # ora i cani guardano in su
        # (x,y) -> (h-1-y, x) con la rotazione oraria
        def rr(r):
            x0,y0_,x1,y1_=r
            return [ (h-y1_)/W, x0/H, (h-y0_)/W, x1/H ]   # rettangolo normalizzato [x0,y0,x1,y1]
        img=cv2.resize(rgba,(int(W*S),int(H*S)),interpolation=cv2.INTER_AREA)
        cv2.imwrite(f'{OUT}/mats/{col}.webp',img,[cv2.IMWRITE_WEBP_QUALITY,90])
        meta[col]={'R':rr(c1),'L':rr(c2),'B':rr((hx0,hy0,hx1,hy1)),'size':[img.shape[1],img.shape[0]]}
        print(col,img.shape,meta[col])
json.dump(meta,open(f'{OUT}/mats/mats.json','w'),indent=1)

# --- allineamento fine delle caselle: confronto con la plancia rossa nella zona delle carte ---
ref=cv2.imread(f'{OUT}/mats/red.webp',cv2.IMREAD_UNCHANGED)
def gray_top(img):
    g=cv2.cvtColor(img[:,:,:3],cv2.COLOR_BGR2GRAY).astype(np.float32)
    g[img[:,:,3]<128]=255
    return g[0:300,0:420]
rg=gray_top(ref); RW,RH=ref.shape[1],ref.shape[0]
for col in list(meta):
    if col=='red': continue
    img=cv2.imread(f'{OUT}/mats/{col}.webp',cv2.IMREAD_UNCHANGED); W,H=img.shape[1],img.shape[0]
    (dx,dy),resp=cv2.phaseCorrelate(rg,gray_top(img))
    # le due carte sono uguali: uno spostamento di una carta intera è un falso allineamento
    pitch=(meta['red']['R'][0]-meta['red']['L'][0])*RW
    while dx>pitch/2: dx-=pitch
    while dx<-pitch/2: dx+=pitch
    for k in ('L','R'):
        r=meta['red'][k]
        px=[r[0]*RW+dx,r[1]*RH+dy,r[2]*RW+dx,r[3]*RH+dy]
        meta[col][k]=[px[0]/W,px[1]/H,px[2]/W,px[3]/H]
    print(col,'spostamento',round(dx,1),round(dy,1),'affidabilità',round(resp,2))
json.dump(meta,open(f'{OUT}/mats/mats.json','w'),indent=1)
