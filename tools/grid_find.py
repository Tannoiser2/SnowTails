import cv2,numpy as np
LW=107.6
def find_cols(a,y0,y1):
    g=cv2.cvtColor(a,cv2.COLOR_BGR2GRAY).astype(float)
    prof=(g[y0:y1,:1250]<150).mean(0)
    cols=[]
    for base in [195,389,583,777,971]:
        w=prof[base-25:base+25]
        cols.append(base-25+int(np.argmax(w)))
    return cols
def lane_rows(a,y0,y1):
    g=cv2.cvtColor(a,cv2.COLOR_BGR2GRAY).astype(float)
    dark=(g<150).astype(float)
    H=np.convolve(dark[:,40:1120].mean(1),np.ones(3)/3,'same')
    cols=find_cols(a,y0,y1)
    V=np.mean([dark[:,c-3:c+4].max(1) for c in cols],axis=0)
    best=None
    for start in np.arange(max(y0,110),y1-5*LW-110,1.0):
        ys=[int(round(start+k*LW)) for k in range(6)]
        h=sum(H[y-2:y+3].max() for y in ys)
        vin=V[ys[0]+5:ys[-1]-5].mean()
        vout=0.5*(V[ys[0]-100:ys[0]-8].mean()+V[ys[-1]+8:ys[-1]+100].mean())
        sc=h+4*(vin-vout)
        if best is None or sc>best[0]: best=(sc,ys,cols)
    return best
