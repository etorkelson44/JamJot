# Fits Erika's Jazzy Joggers and Serenade Sandal (side view) to Presto's crossed legs (her PDF, 144 dpi coordinates of legs.png).
import numpy as np, cv2
from PIL import Image
from scipy.spatial import cKDTree
from scipy.interpolate import CubicSpline
def lay(p): return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32)/255
def over(b,t):
    a=t[...,3:]; ba=b[...,3:]; oa=a+ba*(1-a); return np.concatenate([(t[...,:3]*a+b[...,:3]*ba*(1-a))/np.maximum(oa,1e-6),oa],-1)
PAD=200; W,H=589+2*PAD,989+2*PAD
LEGS=np.zeros((H,W,4),np.float32); LEGS[PAD:PAD+989,PAD:PAD+589]=lay('legs.png')
PANTS=lay('pants.png'); SAND=lay('sandal.png')
al=PANTS[...,3]>0.5; ph,pw=al.shape
cols=np.nonzero(al.any(0))[0]; xc0=(cols.min()+cols.max())//2
# crotch: the column near the middle that is empty lowest down
gap=[(np.nonzero(~al[ph//5:,x])[0].min()+ph//5,x) for x in range(xc0-60,xc0+60)]; CY,XC=min(gap); 
rowL=np.nonzero(al[CY+40,:XC])[0]; rowR=np.nonzero(al[CY+40,XC:])[0]+XC
XL=(rowL.min()+rowL.max())/2; XR=(rowR.min()+rowR.max())/2
if __name__=='__main__': print('pants',pw,ph,'crotch',XC,CY,'leg centres',XL,XR)
def curve(pts,n=1500,straight=2):
    """Centre line: the first `straight` points are joined by a straight (vertical) line, the rest by a smooth curve that leaves it going straight down."""
    pts=np.array(pts,float); a=pts[:straight]; b=pts[straight-1:]
    t=np.r_[0,np.cumsum(np.hypot(*np.diff(b,axis=0).T))]; d0=(a[-1]-a[0])/np.hypot(*(a[-1]-a[0]))
    cs=CubicSpline(t,b,bc_type=((1,d0),(2,np.zeros(2)))); u=np.linspace(0,t[-1],n); P=cs(u)
    m=int(np.hypot(*(a[-1]-a[0]))); line=a[0]+np.outer(np.linspace(0,1,m,endpoint=False),a[-1]-a[0]); P=np.vstack([line,P])
    s=np.r_[0,np.cumsum(np.hypot(*np.diff(P,axis=0).T))]; T=np.gradient(P,axis=0); T/=np.hypot(*T.T)[:,None]; return P,s,T
def ribbon(pts,src_x0,src_x1,src_cx,kw,kl0=None):
    """Draw source columns [src_x0,src_x1) along the centre line pts; whole source height maps onto the line's length."""
    P,s,T=curve(pts); L=s[-1]; kl0=kl0 or L/ph; Sc=(CY+60)*kl0
    yy,xx=np.mgrid[0:H,0:W]; q=np.stack([xx.ravel()-PAD,yy.ravel()-PAD],1).astype(float)
    _,i=cKDTree(P).query(q); dv=q-P[i]; along=(dv*T[i]).sum(1); d=dv[:,0]*T[i][:,1]*-1+dv[:,1]*T[i][:,0]   # + = to the right when walking down the leg... sign fixed below
    d=-(T[i][:,0]*dv[:,1]-T[i][:,1]*dv[:,0])
    S=s[i]+along; my=np.where(S<Sc,S/kl0,CY+60+(S-Sc)*(ph-CY-60)/(L-Sc)).reshape(H,W).astype(np.float32); mx=(src_cx+d/kw).reshape(H,W).astype(np.float32)
    src=PANTS.copy(); src[:,:int(src_x0),3]=0; src[:,int(src_x1):,3]=0; pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1)
    o=cv2.remap(pm,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0); a=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/a,0,1),o[...,3:]],-1)
_yy,_xx=np.mgrid[0:SAND.shape[0],0:SAND.shape[1]]
UPPER=SAND.copy(); UPPER[...,3]*=((_yy<285)|((_yy<321)&(_xx>140)&(_xx<657))).astype(np.float32)   # the strap wall on the near side of the foot
def sandal(scale,angle,flip,anchor_src,anchor_dst,src=None):
    src=SAND if src is None else src; s=src[:,::-1].copy() if flip else src.copy(); h,w=s.shape[:2]; ax,ay=anchor_src; ax=(w-ax) if flip else ax
    M=cv2.getRotationMatrix2D((ax,ay),angle,scale); M[0,2]+=anchor_dst[0]+PAD-ax; M[1,2]+=anchor_dst[1]+PAD-ay
    pm=np.concatenate([s[...,:3]*s[...,3:],s[...,3:]],-1); o=cv2.warpAffine(pm,M,(W,H),flags=cv2.INTER_AREA if scale<1 else cv2.INTER_LINEAR); a=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/a,0,1),o[...,3:]],-1)
def show(layers,name,bg=(1,1,1)):
    c=np.ones((H,W,4),np.float32); c[...,:3]=bg
    for l in layers: c=over(c,l)
    Image.fromarray((c[...,:3]*255).astype('uint8')).save(name)
