# Fits the Jazzy Joggers (ribbon along each leg) and the Serenade Sandals (Erika's layered Keywi sandal, foot-to-foot) to any
# pose, working on the pose's own 1000px canvas (supersampled).
import numpy as np, cv2, json
from PIL import Image
from scipy.spatial import cKDTree
from scipy.interpolate import CubicSpline
AR='/home/claude/jamjot/app/assets/art/'
def lay(p): return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32)/255
def over(b,t):
    a=t[...,3:]; ba=b[...,3:]; oa=a+ba*(1-a); return np.concatenate([(t[...,:3]*a+b[...,:3]*ba*(1-a))/np.maximum(oa,1e-6),oa],-1)
PANTS=lay('/home/claude/pp/pants.png'); ph,pw=PANTS.shape[:2]; XC,CY,XL,XR=391,386,232.5,554.5; CYS=CY+60
FABRIC=np.array([150,110,72])/255
K=3
def curve(pts,n=900,straight=2):
    pts=np.array(pts,float); a=pts[:straight]; b=pts[straight-1:]
    t=np.r_[0,np.cumsum(np.hypot(*np.diff(b,axis=0).T))]; d0=(a[-1]-a[0])/np.hypot(*(a[-1]-a[0]))
    P=CubicSpline(t,b,bc_type=((1,d0),(2,np.zeros(2))))(np.linspace(0,t[-1],n))
    m=max(2,int(np.hypot(*(a[-1]-a[0]))*4)); P=np.vstack([a[0]+np.outer(np.linspace(0,1,m,endpoint=False),a[-1]-a[0]),P])
    s=np.r_[0,np.cumsum(np.hypot(*np.diff(P,axis=0).T))]; T=np.gradient(P,axis=0); T/=np.hypot(*T.T)[:,None]; return P,s,T
def ribbon(pts,side,kw,kl0,roi):
    """One pant leg along the centre line pts (canvas px). roi=(x0,y0,x1,y1) canvas px. Returns a 1000x1000 RGBA layer."""
    x0,y0,x1,y1=roi; P,s,T=curve(pts); L=s[-1]; Sc=CYS*kl0
    yy,xx=np.mgrid[0:(y1-y0)*K,0:(x1-x0)*K]; q=np.stack([xx.ravel()/K+x0,yy.ravel()/K+y0],1)
    _,i=cKDTree(P).query(q); dv=q-P[i]; S=s[i]+(dv*T[i]).sum(1); d=-(T[i][:,0]*dv[:,1]-T[i][:,1]*dv[:,0])
    my=np.where(S<Sc,S/kl0,CYS+(S-Sc)*(ph-CYS)/max(L-Sc,1e-6)).reshape(yy.shape).astype(np.float32)
    mx=((XL if side=='L' else XR)+d/kw).reshape(yy.shape).astype(np.float32)
    src=PANTS.copy()
    if side=='L': src[:,XC+3:,3]=0
    else: src[:,:XC-3,3]=0
    pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1)
    pm=cv2.GaussianBlur(pm,(0,0),max(0.5,0.35/(kw*K)))        # the art is shrunk a lot: soften first so the plaid does not shimmer
    o=cv2.remap(pm,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    o=cv2.resize(o,(x1-x0,y1-y0),interpolation=cv2.INTER_AREA); a=np.maximum(o[...,3:],1e-6)
    out=np.zeros((1000 if y1<=1000 else y1,1000,4),np.float32); out[y0:y1,x0:x1]=np.concatenate([np.clip(o[...,:3]/a,0,1),o[...,3:]],-1); return out
# --- Keywi's sandal, his right foot (toes left) on his canvas ---
KS,KTX,KTY,KT=0.6014101796433589,-101.06716916423636,-62.09641467271149,40
K_HEEL,K_TOE,K_BOTTOM,K_MID=575.0,486.0,1108.0,476.0
def _ksrc(names):
    out=None
    for n in names:
        im=lay(f'/home/claude/kw/{n}.png'); xs=np.arange(im.shape[1])*KS+KTX; im[:,xs<K_MID,3]=0; out=im if out is None else over(out,im)
    return out
KSOLE=_ksrc(['sub_X39']); KSTRAP=_ksrc(['sub_X42','sub_X45','sub_X46'])
def sandal(heel,toe,bottom,size=1000):
    """Sole and strap layers for a flat foot whose heel and toe are at canvas x = heel, toe and whose underside is at y = bottom."""
    k=abs(toe-heel)/(K_HEEL-K_TOE); sgn=1 if toe>heel else -1      # u = K_HEEL-(KS*x+KTX) from heel to toe; X = heel+sgn*u*k
    M=np.float32([[-sgn*KS*k,0,heel+sgn*(K_HEEL-KTX)*k],[0,KS*k,bottom-(K_BOTTOM-KTY-KT)*k]]); out=[]
    for src in (KSOLE,KSTRAP):
        pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1); o=cv2.warpAffine(pm,M,(1000,size),flags=cv2.INTER_AREA); a=np.maximum(o[...,3:],1e-6)
        out.append(np.concatenate([np.clip(o[...,:3]/a,0,1),np.clip(o[...,3:],0,1)],-1))
    return out
# --- reading a pose ---
def legs_of(tag):
    m=json.load(open(AR+tag+'/manifest.json')); leg=[l for l in m['layers'] if 'legs' in l][0]; return m,leg,lay(AR+tag+f'/{leg}.png')
def leg_info(a,left):
    """Centre line samples, foot top row, and the flat extents of the foot for one leg (left or right half of the layer)."""
    al=a[...,3]>0.5; xs=np.nonzero(al.any(0))[0]; mid=(xs.min()+xs.max())//2; h=al.copy()
    if left: h[:,mid:]=False
    else: h[:,:mid]=False
    rows=np.nonzero(h.any(1))[0]; top,bot=rows.min(),rows.max()
    wid={y:(np.nonzero(h[y])[0].min(),np.nonzero(h[y])[0].max()) for y in rows}
    stroke=np.median([b-a_ for y,(a_,b) in wid.items() if y<top+(bot-top)*0.6])
    foot_top=min(y for y,(a_,b) in wid.items() if b-a_>2.2*stroke and y>top+(bot-top)*0.5)
    cl=[((wid[y][0]+wid[y][1])/2,y) for y in range(top+4,foot_top-2)]
    fx0,fx1=wid[bot-3]; return dict(cl=cl,top=top,bot=bot,foot_top=foot_top,fx=(fx0,fx1),stroke=stroke)
def joggers_two_legs(a,kw,waist_y,cuff_gap=5,roi_pad=60,hips=None,ends=None):
    """Pants for two roughly upright legs. Returns layers A (viewer-left leg) and B, plus the crotch row."""
    Li,Ri=leg_info(a,True),leg_info(a,False); cuff=min(Li['foot_top'],Ri['foot_top'])-cuff_gap if ends is None else ends[2]
    Ltot=cuff-waist_y; kl0=Ltot/ph; crotch=waist_y+CYS*kl0; h=(XC-XL)*kw
    def cx(info,y): 
        c=np.array(info['cl']); return float(np.interp(y,c[:,1],c[:,0]))
    mid=((cx(Li,cuff)+cx(Ri,cuff))/2 if ends is None else (ends[0]+ends[1])/2) if hips is None else hips      # centred over the ankles, so both pant legs lean by the same amount
    out=[]
    for info,side,sg in ((Li,'L',-1),(Ri,'R',1)):
        hipx=mid+sg*h; ax=cx(info,cuff) if ends is None else ends[0 if side=='L' else 1]
        # straight down through the hips, then a gentle line to the ankle (the legs above the cuff are hidden: see trimmed_legs)
        pts=[(hipx,waist_y),(hipx,crotch),(hipx+(ax-hipx)*0.45,crotch+(cuff-crotch)*0.5),(ax,cuff)]
        x0=int(min(p[0] for p in pts)-roi_pad); x1=int(max(p[0] for p in pts)+roi_pad); out.append(ribbon(pts,side,kw,kl0,(max(x0,0),int(waist_y-12),min(x1,1000),int(cuff+25))))
    return out[0],out[1],crotch,(Li,Ri),cuff
def gusset(A,B,body_alpha,crotch):
    """Plain fabric where the body would show between the pant legs below the crotch; merged under A."""
    cy=int(crotch); pal=np.maximum(A[...,3],B[...,3]); xs=np.nonzero(pal[cy-2:cy+3].max(0)>0.5)[0]; g=np.zeros_like(A)
    if len(xs)==0: return A
    reg=np.zeros(pal.shape,bool); reg[cy:,xs.min():xs.max()]=True; b=np.zeros(pal.shape,np.float32); b[:body_alpha.shape[0]]=body_alpha
    g[...,:3]=FABRIC; g[...,3]=cv2.GaussianBlur((cv2.dilate((b>0.5).astype(np.uint8),np.ones((5,5),np.uint8))>0).astype(np.float32)*reg,(0,0),0.7)
    return over(g,A)
def flat(layers,size=1000,bg=True):
    c=np.ones((size,1000,4),np.float32) if bg else np.zeros((size,1000,4),np.float32)
    for l in layers:
        if l.shape[0]<size: l=np.vstack([l,np.zeros((size-l.shape[0],1000,4),np.float32)])
        c=over(c,l[:size])
    return c
def img(c): return Image.fromarray((np.clip(c[...,:3],0,1)*255).round().astype('uint8'))

def trimmed_legs(a,cuff,keep=10):
    """The legs layer with everything above the pant cuffs removed, so no leg shows outside the pants."""
    o=a.copy(); o[:int(cuff-keep),:,3]=0; return o

def seat_fill(body_alpha,mid_x,waist_y,kw,kl,start=2,shade=0.9):
    """Plaid fabric over every part of the body that would show below the waistband (behind and beside the pants), so
    no body peeks out. Texture is the pants' own hip block, mirrored sideways and repeated downward to cover the area."""
    yy,xx=np.mgrid[0:1000,0:1000].astype(np.float32); sx=XC+(xx-mid_x)/kw; sy=(yy-waist_y)/kl
    al=PANTS[...,3]>0.5; r=np.nonzero(al[int(CY*0.6)])[0]; x0,x1=float(r.min()+25),float(r.max()-25); w=x1-x0
    u=np.mod(sx-x0,2*w); sx=x0+np.where(u>w,2*w-u,u)                      # mirror across the hip block's sides
    y0,y1=265.0,float(CY-30); hh=y1-y0; v=np.mod(sy-y0,2*hh); sy=y0+np.where(v>hh,2*hh-v,v)     # plain plaid rows only (below the bow, above the crotch)
    pm=cv2.GaussianBlur(PANTS[...,:3],(0,0),max(0.5,0.35/kw)); tex=cv2.remap(pm,sx.astype(np.float32),sy.astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_REFLECT)*shade
    reg=np.zeros((1000,1000),np.float32); reg[int(waist_y+start):]=1
    m=cv2.GaussianBlur((cv2.dilate((body_alpha>0.5).astype(np.uint8),np.ones((5,5),np.uint8))>0).astype(np.float32)*reg,(0,0),0.7)
    return np.concatenate([tex,m[...,None]],-1)
