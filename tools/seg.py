import cv2,numpy as np
from scipy import ndimage as ndi
def load(pg): return cv2.imread(f'/tmp/p200/p-{pg:02d}.png')
def line_mask(a):
    hsv=cv2.cvtColor(a,cv2.COLOR_BGR2HSV);H,S,V=[hsv[...,i].astype(int) for i in range(3)]
    red=(((H<12)|(H>168))&(S>90)&(V>90))
    return ((V<165)&(S<120))|((H>95)&(H<140)&(S>45)&(V<235))|red
def cells(a,dil=6,amin=2500,amax=110000):
    L=ndi.binary_dilation(line_mask(a),iterations=dil)
    lab,n=ndi.label(~L)
    s=ndi.sum(np.ones_like(lab),lab,range(n+1))
    keep=[i for i in range(1,n+1) if amin<s[i]<amax]
    out={}
    for i in keep:
        sl=ndi.find_objects((lab==i).astype(int))[0]
        m=lab[sl]==i
        ys,xs=np.nonzero(m)
        fill=m.sum()/((np.ptp(ys)+1)*(np.ptp(xs)+1))
        out[i]=dict(c=np.array([xs.mean()+sl[1].start,ys.mean()+sl[0].start]),area=int(s[i]),sl=sl,fill=fill)
    return lab,out
def boundaries(a,lab,cs,r=10):
    hsv=cv2.cvtColor(a,cv2.COLOR_BGR2HSV)
    g=cv2.cvtColor(a,cv2.COLOR_BGR2GRAY)
    dark=g<200
    res={}
    ids=list(cs)
    dil={}
    for i in ids:
        sl=cs[i]['sl'];y0=max(0,sl[0].start-r-2);x0=max(0,sl[1].start-r-2);y1=sl[0].stop+r+2;x1=sl[1].stop+r+2
        m=lab[y0:y1,x0:x1]==i
        dil[i]=(y0,x0,ndi.binary_dilation(m,iterations=r))
    for i in ids:
        y0,x0,d=dil[i]
        sub=lab[y0:y0+d.shape[0],x0:x0+d.shape[1]]
        for j in np.unique(sub[d]):
            j=int(j)
            if j<=i or j not in cs: continue
            Y0,X0,D=dil[j]
            yy0,xx0=max(y0,Y0),max(x0,X0);yy1=min(y0+d.shape[0],Y0+D.shape[0]);xx1=min(x0+d.shape[1],X0+D.shape[1])
            if yy1<=yy0 or xx1<=xx0: continue
            z=d[yy0-y0:yy1-y0,xx0-x0:xx1-x0]&D[yy0-Y0:yy1-Y0,xx0-X0:xx1-X0]
            zz=z&dark[yy0:yy1,xx0:xx1]
            if zz.sum()<12: continue
            px=hsv[yy0:yy1,xx0:xx1][zz]; gg=g[yy0:yy1,xx0:xx1][zz]
            ys,xs=np.nonzero(z)
            # lunghezza del confine e spessore medio della linea
            length=max(np.ptp(xs),np.ptp(ys))+1
            if length<45: continue   # contatto solo per lo spigolo: non è un confine
            res[(i,j)]=dict(v=float(np.percentile(gg,20)),s=float(np.median(px[:,1])),h=float(np.median(px[:,0])),
                            n=int(zz.sum()),len=int(length),thick=float(zz.sum()/max(length,1)),
                            mid=np.array([xs.mean()+xx0,ys.mean()+yy0]))
    return res
