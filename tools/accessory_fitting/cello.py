from fit2 import *
from PIL import ImageDraw, ImageFont
TAG='avatar_instrument/jalapeno_cello'
def straight(p0,p1,side,kw,sy0,sy1,roi,round_start=0,round_hw=0,cx=None):
    """One straight piece of a pant leg from p0 to p1 (canvas px), showing source rows sy0..sy1 of that leg."""
    x0,y0,x1,y1=roi; p0=np.array(p0,float); p1=np.array(p1,float); L=np.hypot(*(p1-p0)); T=(p1-p0)/L
    yy,xx=np.mgrid[0:(y1-y0)*K,0:(x1-x0)*K]; q=np.stack([xx.ravel()/K+x0,yy.ravel()/K+y0],1)-p0
    S=q@T; d=-(T[0]*q[:,1]-T[1]*q[:,0]); my=(sy0+S/L*(sy1-sy0)); mx=((XL if side=='L' else XR) if cx is None else (cx if side=='L' else 2*XC-cx))+d/kw
    my=np.where((S<0)|(S>L),-10,my).reshape(yy.shape).astype(np.float32); mx=mx.reshape(yy.shape).astype(np.float32)
    src=PANTS.copy()
    if side=='L': src[:,XC+3:,3]=0
    else: src[:,:XC-3,3]=0
    pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1); pm=cv2.GaussianBlur(pm,(0,0),max(0.5,0.35/(kw*K)))
    o=cv2.remap(pm,mx,my,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    if round_start:   # round the outer corner at the start of this piece (the knee)
        hw=round_hw; r=round_start; Sg=S.reshape(yy.shape); dg=np.abs(d).reshape(yy.shape)
        cut=(Sg<r)&(dg>hw-r)&(((r-Sg)**2+(dg-(hw-r))**2)>r*r); o[cut]=0
    o=cv2.resize(o,(x1-x0,y1-y0),interpolation=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6)
    out=np.zeros((1000,1000,4),np.float32); out[y0:y1,x0:x1]=np.concatenate([np.clip(o[...,:3]/al,0,1),o[...,3:]],-1); return out
def build():
    """Seated: each pant leg is a straight thigh piece and a straight shin piece that overlaps it at the knee (a folded
    knee, not a curve, so the plaid stays straight on both pieces)."""
    m,leg,a=legs_of(TAG); Li,Ri=leg_info(a,True),leg_info(a,False); kw=.22; hw=(XC-XL)*kw; mid=478.0; cuff=min(Li['foot_top'],Ri['foot_top'])-5
    ty=803.0; knee=303.0; split=CYS+(ph-CYS)*0.60      # source rows: thigh gets 60% of the leg, shin the rest
    def meas(row,side):
        r=np.nonzero(PANTS[int(row),:XC,3]>0.5)[0] if side=='L' else np.nonzero(PANTS[int(row),XC:,3]>0.5)[0]+XC
        c=(r.max()+r.min())/2; return (r.max()-r.min())/2*kw, (c if side=='L' else 2*XC-c)     # half width, centre (as a left-leg column)
    out=[]
    for side,sg in (('L',1),('R',-1)):
        X=lambda x: x if sg>0 else 2*mid-x
        hwk,cxs=meas(split,side); _,cxt=meas((CYS+split)/2,side)
        roi=(200,740,520,930) if sg>0 else (440,740,760,930)
        hip=straight((X(mid-hw),752),(X(mid-hw),ty),side,kw,0,CYS,roi)
        thigh=straight((X(mid-8),ty),(X(knee),ty),side,kw,CYS,split,roi,cx=cxt)
        _t=np.nonzero(thigh[:,int(X(knee+6)),3]>0.5)[0]; ttop=float(_t.min())      # top line of the thigh at the knee
        shin=straight((X(knee),ttop),(X(knee+1),cuff),side,kw,split-60,ph,roi,round_start=16,round_hw=hwk,cx=cxs)   # shin starts level with it
        # a soft fold line where the shin hangs over the thigh
        sh=np.zeros_like(shin); sm=cv2.GaussianBlur(shin[...,3],(0,0),2.2); sh[...,3]=np.clip(sm-shin[...,3],0,1)*0.30*(thigh[...,3]>0.5)
        out.append(over(over(over(hip,thigh),sh),shin))
    A,B=out
    g=np.zeros_like(A); poly=np.array([[mid-hw,770],[mid+hw,770],[mid+hw+28,838],[mid-hw-28,838]],np.int32); mk=np.zeros(A.shape[:2],np.uint8); cv2.fillPoly(mk,[poly],255)
    g[...,:3]=FABRIC; g[...,3]=cv2.GaussianBlur(mk.astype(np.float32)/255,(0,0),0.8); A=over(g,A)
    sL=sandal(Li['fx'][1],Li['fx'][0],Li['bot']); sR=sandal(Ri['fx'][0],Ri['fx'][1],Ri['bot'])
    return dict(m=m,leg=leg,A=A,B=B,legs_trim=trimmed_legs(a,cuff),soles=over(sL[0],sR[0]),straps=over(sL[1],sR[1]))
if __name__=='__main__':
    import apart
    P=build(); cols=[('Plain',[]),('Serenade Sandals',['sandals']),('Jazzy Joggers',['joggers']),('Joggers + Sandals',['joggers','sandals'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22); cw=420; W=Image.new('RGB',(cw*4,cw+40),'white'); d=ImageDraw.Draw(W)
    for ci,(nm,wh) in enumerate(cols):
        im=apart.pose(TAG,P,wh); W.paste(im.resize((cw,cw),Image.LANCZOS),(ci*cw,40)); d.text((ci*cw+10,8),'cello: '+nm,fill=(60,40,110),font=f)
    W.save('Presto_cello_draft.png'); im.crop((200,700,760,960)).resize((1680,780),Image.LANCZOS).save('cello_zoom.png')
