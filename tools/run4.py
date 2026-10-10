import cv2,numpy as np,json
from automap import automap,draw
FACES={
 'corner_L_p07':(7,(361,1562.5),(425,-400),(689.5,0),(0,-1)),
 'corner_R_p08':(8,(827,1562),(-426,-398),(494,0),(0,-1)),
 'uturn_R_p02':(2,(0,467.5),(1,0),(0,1639.5),(-1,0)),
 'uturn_L_p01':(1,(0,1645),(1,0),(0,472.5),(-1,0)),
}
out={}
for fid,(pg,em,ed,xm,xd) in FACES.items():
    r=automap(pg,em,ed,xm,xd,fid)
    num=draw(r,f'{fid}.jpg',0.45)
    # mappa copertura: regioni colorate a caso, bianco = non riconosciuto
    a=r['a'];lab=r['lab'];rng=np.random.RandomState(1);v=(a*0.35).astype(np.uint8)
    for i in r['ids']: v[lab==i]=rng.randint(90,255,3)
    cv2.imwrite(f'{fid}_cov.jpg',cv2.resize(v,(v.shape[1]*45//100,v.shape[0]*45//100)))
    out[fid]=r
    print(fid,'celle',len(r['ids']),'avanti',len(r['links']),'ingresso',len(r['ent']),'uscita',len(r['ext']),'dubbie',len(r['doubt_c']))
import pickle;pickle.dump({k:{kk:vv for kk,vv in v.items() if kk not in('a','lab')} for k,v in out.items()},open('res.pkl','wb'))
