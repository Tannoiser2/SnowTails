# Estrae le facce delle tessere dalle scansioni a 200 dpi e scrive immagini (100 dpi) + JSON.
import cv2,numpy as np,json,os
from scipy import ndimage as ndi
SRC='/tmp/p200/p-%02d.png'; OUT='/tmp/proj'
S=0.5   # coordinate: 200 dpi -> 100 dpi
TEXS=0.75  # texture: 150 dpi
LW=107.6
def page(pg): return cv2.imread(SRC%pg)
from mask2 import tile_mask2
def tile_mask(a):
    return tile_mask2(a)
def _old_tile_mask(a):
    g=a.min(axis=2); bgc=(g>=249)
    lab,n=ndi.label(bgc)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    fg=~np.isin(lab,list(border))
    fg=ndi.binary_opening(fg,iterations=2)
    return fg
def lines(a):
    hsv=cv2.cvtColor(a,cv2.COLOR_BGR2HSV);H,Sa,V=[hsv[...,i].astype(int) for i in range(3)]
    return ((V<165)&(Sa<120))|((H>95)&(H<140)&(Sa>45)&(V<235))
def hints(a,mask,dil=6):
    L=ndi.binary_dilation(lines(a),iterations=dil)
    lab,n=ndi.label(~L&mask)
    s=ndi.sum(np.ones_like(lab),lab,range(n+1)); com=ndi.center_of_mass(np.ones_like(lab),lab,range(n+1))
    out=[]
    for i in range(1,n+1):
        if 2500<s[i]<110000:
            m=(lab==i); ys,xs=np.nonzero(m)
            # cella compatta: rapporto area/bbox ragionevole
            if s[i]/((np.ptp(ys)+1)*(np.ptp(xs)+1))>0.25: out.append([com[i][1],com[i][0]])
    return out
def save(fid,a,mask,box,meta):
    x0,y0,x1,y1=box
    crop=a[y0:y1,x0:x1]; m=mask[y0:y1,x0:x1]
    rgba=np.dstack([crop,(m*255).astype(np.uint8)])
    rgba=cv2.resize(rgba,(int(round((x1-x0)*TEXS)),int(round((y1-y0)*TEXS))),interpolation=cv2.INTER_AREA)
    rgba[:,:,3]=np.where(rgba[:,:,3]>127,255,0).astype(np.uint8)
    cv2.imwrite(f'{OUT}/assets/tiles/{fid}.webp',rgba,[cv2.IMWRITE_WEBP_QUALITY,90])
    def tr(p): return [round((p[0]-x0)*S,1),round((p[1]-y0)*S,1)]
    d=dict(id=fid,image=f'res://assets/tiles/{fid}.webp',img_scale=TEXS/S,size=[round((x1-x0)*S,1),round((y1-y0)*S,1)],lane_width=round(LW*S,2),**{k:v for k,v in meta.items() if k not in('lanes','hints','entry','exit')})
    d['entry']=dict(mid=tr(meta['entry'][0]),dir=meta['entry'][1])
    d['exit']=dict(mid=tr(meta['exit'][0]),dir=meta['exit'][1])
    lanes=meta.get('lanes',[[]]*5)
    cells=[];links=[]
    for l in lanes:
        prev=-1
        for p in l:
            if p is None: prev=-1; continue
            idx=len(cells); cells.append(tr(p))
            if prev>=0: links.append([prev,idx])
            prev=idx
    d['cells']=cells; d['links']=links
    crev=meta.get('crevasse_pts',[])
    d['crevasse']=[i for i,c in enumerate(cells) if any(abs(c[0]-tr(q)[0])<3 and abs(c[1]-tr(q)[1])<3 for q in crev)]
    if not d['crevasse']: d.pop('crevasse')
    sap=meta.get('saplings_pts',[])
    d['saplings']=[i for i,c in enumerate(cells) if any(abs(c[0]-tr(q)[0])<3 and abs(c[1]-tr(q)[1])<3 for q in sap)]
    d.pop('blocked',None)
    d['hints']=[tr(p) for p in meta.get('hints',[])]
    d['mapped']=len(cells)>0
    json.dump(d,open(f'{OUT}/data/faces/{fid}.json','w'),ensure_ascii=False,indent=1)
    print(fid,'mapped' if d['mapped'] else 'DA MAPPARE',rgba.shape)
def bbox(m):
    ys,xs=np.nonzero(m); return [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
def unit(v): v=np.array(v,float); return list(np.round(v/np.linalg.norm(v),4))

# ---------- caselle speciali ----------
GEOM={}
SPECIAL={}   # fid -> dict(saplings=[(col,row)], blocked=[(col,row)]) col/row nella griglia dell'immagine
def special_cells(a,cols,ytop,lw,kind):
    return SPECIAL_CUR.get('v')
SPECIAL_CUR={}
def apply_special(lanes,extra):
    # lanes[k][j]: k corsia (0=riga in basso), j indice da destra. Convertiamo in (col,row) immagine
    out=[]
    ncol=len(lanes[0])
    for k,l in enumerate(lanes):
        nl=[]
        for j,p in enumerate(l):
            col=ncol-1-j; row=4-k
            if (col,row) in extra['blocked']: nl.append(None)
            else: nl.append(p)
        out.append(nl)
    return out

# ---------- rettilinei semplici (6 x 5) ----------
def straight(fid,pg,half,label,kind=''):
    from grid_find import lane_rows
    a=page(pg); mask=tile_mask(a); h=a.shape[0]
    top=lane_rows(a,0,1050); bot=lane_rows(a,950,h)
    ys,cols=(top[1],top[2]) if half=='top' else (bot[1],bot[2])
    split=int((top[1][-1]+bot[1][0])/2)
    m=mask.copy()
    if half=='top': m[split:]=False
    else: m[:split]=False
    m[:max(0,ys[0]-260)]=False; m[ys[-1]+260:]=False; m[:,1190:]=False
    lab,n=ndi.label(m); sizes=ndi.sum(m,lab,range(1,n+1)); m=lab==(1+int(np.argmax(sizes)))
    m=ndi.binary_fill_holes(m)
    x0,y0,x1,y1=bbox(m)
    ytop,ybot=ys[0],ys[-1]
    xs=[x0]+list(cols)+[x0+int(round((cols[-1]-x0)*6/5))]
    xs[-1]=min(xs[-1],x1)
    lw=(ybot-ytop)/5
    # verso di marcia: da destra a sinistra; corsia 0 (sinistra) = riga in basso
    grid={}
    for c in range(6):
        for r in range(5):
            grid[(c,r)]=[(xs[c]+xs[c+1])/2, ytop+lw*(r+.5)]
    sp=SPECIAL.get(fid,{})
    blocked=set(tuple(x) for x in sp.get('blocked',[]))
    lanes=[]
    for k in range(5):
        r=4-k
        lanes.append([None if (c,r) in blocked else grid[(c,r)] for c in range(5,-1,-1)])
    sap=[grid[tuple(x)] for x in sp.get('saplings',[])]
    crev=[grid[tuple(x)] for x in sp.get('crevasse',[])]
    ym=(ytop+ybot)/2
    GEOM[fid]=dict(page=pg,cols=xs,ytop=ytop,ybot=ybot,box=(x0,y0,x1,y1))
    save(fid,a,m,(x0,y0,x1,y1),dict(label=label,type='straight',turn='',limit=0,special=kind,
        entry=((xs[-1],ym),[-1,0]),exit=((x0,ym),[-1,0]),lanes=lanes,saplings_pts=sap,crevasse_pts=crev,
        **({'leap_min':sp['leap_min']} if 'leap_min' in sp else {})))

import sys
FACES=[('p13a',13,'top'),('p13b',13,'bottom'),('p14a',14,'top'),('p14b',14,'bottom'),('p15a',15,'top'),('p15b',15,'bottom'),
       ('p16a',16,'top'),('p16b',16,'bottom'),('p17a',17,'top'),('p17b',17,'bottom'),('p18a',18,'top'),('p18b',18,'bottom'),
       ('p19a',19,'top'),('p19b',19,'bottom'),('p20a',20,'top'),('p20b',20,'bottom'),('p22a',22,'top')]
exec(open('specials.py').read()) if os.path.exists('specials.py') else None
for key,pg,half in FACES:
    info=KINDS.get(key,('straight','Rettilineo',''))
    try:
        straight(info[0]+'_'+key,pg,half,f'{info[1]} (p.{pg} {"sopra" if half=="top" else "sotto"})',info[2])
    except Exception as e:
        print('ERRORE',key,e)
json.dump(GEOM,open('/tmp/b/geom.json','w'))

# ---------- partenza e arrivo (pagina 21) ----------
a=page(21); mask=tile_mask(a)
def region_part(mask,y0,y1,x0,x1):
    reg=np.zeros_like(mask); reg[y0:y1,x0:x1]=True
    lab,n=ndi.label(mask&reg); sizes=ndi.sum(mask&reg,lab,range(1,n+1))
    return ndi.binary_fill_holes(lab==(1+int(np.argmax(sizes))))
fm=region_part(mask,940,1890,0,430); fb=bbox(fm)
fy=[1664-LW*(k+.5) for k in range(5)]
save('finish_p21',a,fm,fb,dict(label='Arrivo (p.21)',type='finish',turn='',limit=0,
    entry=((386,1395),[-1,0]),exit=((fb[0],1395),[-1,0]),lanes=[[[280,y],[91,y]] for y in fy]))
sm=region_part(mask,940,1950,440,1250); sb=bbox(sm)
sy=[1685-LW*(k+.5) for k in range(5)]
save('start_p21',a,sm,sb,dict(label='Partenza (p.21)',type='start',turn='',limit=0,
    entry=((sb[2],1416),[-1,0]),exit=((sb[0],1416),[-1,0]),lanes=[[[576,y]] for y in sy]))

# ---------- partenza e arrivo (pagina 22: posizione 1 a destra) ----------
a=page(22); mask=tile_mask(a)
fm=region_part(mask,1000,1950,0,430); fb=bbox(fm)
fy=[1706-LW*(k+.5) for k in range(5)]
save('finish_p22',a,fm,fb,dict(label='Arrivo (p.22)',type='finish',turn='',limit=0,
    entry=((368,1437),[-1,0]),exit=((fb[0],1437),[-1,0]),lanes=[[[270,y],[92,y]] for y in fy]))
sm=region_part(mask,1000,2000,440,1250); sb=bbox(sm)
sy=[1153+LW*(k+.5) for k in range(5)]   # posizione 1 in alto = a destra nel senso di marcia
save('start_p22',a,sm,sb,dict(label='Partenza (p.22)',type='start',turn='',limit=0,
    entry=((sb[2],1422),[-1,0]),exit=((sb[0],1422),[-1,0]),lanes=[[[576,y]] for y in sy]))

# ---------- curve e inversioni: ingressi/uscite misurati, caselle da mappare ----------
def special(fid,pg,label,typ,turn,limit,entry_mid,entry_dir,exit_mid,exit_dir):
    a=page(pg); mask=tile_mask(a); mask=ndi.binary_fill_holes(mask)
    lab,n=ndi.label(mask); sizes=ndi.sum(mask,lab,range(1,n+1)); m=lab==(1+int(np.argmax(sizes)))
    m=ndi.binary_fill_holes(m)
    hs=hints(a,m)
    save(fid,a,m,bbox(m),dict(label=label,type=typ,turn=turn,limit=limit,
        entry=(entry_mid,unit(entry_dir)),exit=(exit_mid,unit(exit_dir)),hints=hs))
# curve: ingresso sul lato obliquo con i cartelli, uscita sul lato dritto in alto
special('corner_L_p07',7,'Curva a sinistra (p.7)','corner','L',4,(361,1562.5),(425,-400),(689.5,0),(0,-1))
special('corner_R_p08',8,'Curva a destra (p.8)','corner','R',4,(827,1562),(-426,-398),(494,0),(0,-1))
# inversioni: ingresso e uscita sul lato sinistro
special('uturn_R_p02',2,'Inversione a destra (p.2)','uturn','R',3,(0,467.5),(1,0),(0,1639.5),(-1,0))
special('uturn_L_p01',1,'Inversione a sinistra (p.1)','uturn','L',3,(0,1645),(1,0),(0,472.5),(-1,0))
