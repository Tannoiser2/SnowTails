import cv2,numpy as np
from scipy import ndimage as ndi
def tile_mask2(a, r=14):
    nonbg=(a.min(axis=2)<254)
    k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(2*r+1,2*r+1))
    m=cv2.morphologyEx(nonbg.astype(np.uint8),cv2.MORPH_CLOSE,k)>0
    m=ndi.binary_fill_holes(m)
    m=cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(31,31)))>0
    # strisce sottili lungo i bordi dello scanner: righe/colonne con pochissimi pixel
    lab,n=ndi.label(m)
    out=np.zeros_like(m)
    for i in range(1,n+1):
        c=lab==i
        if c.sum()<20000: continue
        rows=c.sum(1); cols=c.sum(0)
        c[rows<40,:]=False; c[:,cols<40]=False
        out|=c
    out=cv2.morphologyEx(out.astype(np.uint8),cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))>0
    # strisce larghe (bordo del coperchio dello scanner, ~45 px): un'apertura grande trova il corpo
    # della tessera, poi si recuperano solo i dettagli del contorno vicini al corpo
    # fuori dall'immagine conta come vuoto, altrimenti le strisce lungo il bordo sopravvivono
    body=cv2.morphologyEx(out.astype(np.uint8),cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(75,75)),
                          borderType=cv2.BORDER_CONSTANT,borderValue=0)>0
    near=cv2.dilate(body.astype(np.uint8),cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(41,41)))>0
    out=body|(out&near)
    lab,n=ndi.label(out)
    if n>1:
        sz=ndi.sum(out,lab,range(1,n+1))
        out=np.isin(lab,[i+1 for i,v in enumerate(sz) if v>20000])
    return out
if __name__=='__main__':
    ims=[]
    for pg in (13,7,2,21):
        a=cv2.imread(f'/tmp/p200/p-{pg:02d}.png');m=tile_mask2(a)
        v=a.copy();v[~m]=(180,60,180)
        ims.append(cv2.resize(v,(413,584)))
    cv2.imwrite('mask2.jpg',np.hstack(ims))
