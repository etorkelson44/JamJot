import sys, json, os, shutil, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; SRC=A+'avatar_instrument/jalapeno_electric_guitar/'; OUT='/home/claude/ri/pose_bass_guitar/'; os.makedirs(OUT,exist_ok=True)
for f in os.listdir(SRC): shutil.copy(SRC+f,OUT+f)
g=F.lay(SRC+'7_guitar.png'); ys,xs=np.nonzero(g[...,3]>0.5); P=np.stack([xs,ys],1).astype(float); c=P.mean(0); u,s,vt=np.linalg.svd(P-c,full_matrices=False); ax=vt[0]; ax=ax if ax[0]>0 else -ax
pr=(P-c)@ax; Lg=pr.max()-pr.min(); ang_g=np.degrees(np.arctan2(-ax[1],ax[0])); print('guitar length',Lg,'angle above level',ang_g)
src=np.asarray(Image.open('bass_guitar2.png').convert('RGBA')).astype(np.float32)/255; sh,sw=src.shape[:2]
sy,sx=np.nonzero(src[...,3]>0.5); SP=np.stack([sx,sy],1).astype(float); sc=SP.mean(0); _,_,svt=np.linalg.svd((SP-sc)[::50],full_matrices=False); sax=svt[0]; sax=sax if sax[0]>0 else -sax; spr=(SP-sc)@sax; SL=spr.max()-spr.min(); sang=np.degrees(np.arctan2(-sax[1],sax[0])); print('source angle',sang,'length',SL)
ANG=float(sys.argv[1]) if len(sys.argv)>1 else 34.0; LEN=float(sys.argv[2]) if len(sys.argv)>2 else 1.15*Lg; k=LEN/SL
th=np.radians(sang-ANG); R=np.array([[np.cos(th),-np.sin(th)],[np.sin(th),np.cos(th)]])*k
strum=F.lay(SRC+'9_strum_arm_hand.png'); ys,xs=np.nonzero(strum[...,3]>0.5); hand=np.array([xs.max()-14.0,ys[xs>xs.max()-25].mean()]); print('strum hand',hand)
pick=np.array([0.215*sw,0.765*sh]); t=hand-R@pick; M=np.float32(np.hstack([R,t[:,None]]))
pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1); pm=cv2.GaussianBlur(pm,(0,0),0.4/k); o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); bass=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
ys,xs=np.nonzero(bass[...,3]>0.5); print('bass bbox',xs.min(),ys.min(),xs.max(),ys.max())
def put(x,n): Image.fromarray((np.clip(x,0,1)*255).round().astype('uint8')).save(OUT+n)
os.remove(OUT+'7_guitar.png'); put(bass,'7_bass_guitar.png')
# fretting arm: from the shoulder to the neck near the 2nd-3rd fret, hand wrapped round the neck (arm behind, fingertips in front)
FRET=float(sys.argv[3]) if len(sys.argv)>3 else 0.235
neck=R@np.array([0.735*sw,0.268*sh])+t; axis=R@sax; axis/=np.hypot(*axis); nrm=np.array([-axis[1],axis[0]]); nrm=nrm if nrm[1]>0 else -nrm
old=F.lay(SRC+'6_fret_arm.png'); ys,xs=np.nonzero(old[...,3]>0.5); S=np.array([xs.min()+6.0,ys[xs<xs.min()+10].mean()]); w=2*cv2.distanceTransform((old[...,3]>0.5).astype(np.uint8),cv2.DIST_L2,5).max(); print('shoulder',S,'neck point',neck,'reach',np.hypot(*(neck-S)),'old reach',xs.max()-xs.min(),'w',w)
def strokes(lines):
    S4=4; im=np.zeros((4000,4000),np.uint8)
    for a,b,ww in lines:
        cv2.line(im,tuple(np.round(a*S4).astype(int)),tuple(np.round(b*S4).astype(int)),255,int(round(ww*S4)),cv2.LINE_AA)
        for r in (a,b): cv2.circle(im,tuple(np.round(r*S4).astype(int)),int(round(ww*S4/2)),255,-1,cv2.LINE_AA)
    o=np.zeros((1000,1000,4),np.float32); o[...,3]=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA)/255; return o
# arm: same line thickness as his other arm; it ends behind the neck, where the old arm ended behind the guitar's neck
sa=strum[...,3]>0.5; yy_,xx_=np.nonzero(sa); w=2*cv2.distanceTransform(sa.astype(np.uint8),cv2.DIST_L2,5)[yy_.min():yy_.min()+30].max(); print('arm width',w)
put(strokes([(S,neck,w)]),'6_fret_arm.png')
# fingertips: the same small fingertips he has on the other guitars, moved to the new spot and turned with the neck
tip=F.lay('/home/claude/ri/eg_fingertips_before.png'); ty,tx=np.nonzero(tip[...,3]>0.5); tc=np.array([tx.mean(),ty.mean()]); M2=cv2.getRotationMatrix2D((float(tc[0]),float(tc[1])),ANG-ang_g,1.0); M2[:,2]+=neck-tc
pm2=np.concatenate([tip[...,:3]*tip[...,3:],tip[...,3:]],-1); o2=cv2.warpAffine(pm2,M2,(1000,1000),flags=cv2.INTER_LINEAR); al2=np.maximum(o2[...,3:],1e-6); tp=np.concatenate([np.clip(o2[...,:3]/al2,0,1),np.clip(o2[...,3:],0,1)],-1); sys.path.insert(0,'/home/claude/ri'); from nudge import nudge_upper; tp,dxb=nudge_upper(tp,bass[...,3]>0.5); print('bass upper finger moved right',dxb); put(tp,'8_fingertips.png')
# thumb like the electric guitar's: the arm's last stretch turns up through the neck and ends, rounded, just past its top edge
nup=nrm if nrm[1]<0 else -nrm; hw=0.027*sw*k; u=axis*np.cos(np.radians(12))+nup*np.sin(np.radians(12))
T_=neck-axis*20+nup*(hw+7); K_=T_-u*36      # the arm comes in along the top side of the neck and its rounded end (the thumb) sits just above the top edge, beside the fingers
put(strokes([(S,K_,w),(K_,T_,w)]),'6_fret_arm.png')
m=json.load(open(OUT+'manifest.json')); m['layers']=[l.replace('7_guitar','7_bass_guitar') for l in m['layers']]; json.dump(m,open(OUT+'manifest.json','w'),indent=2)
c=np.ones((1000,1000,4),np.float32)
for l in m['layers']: c=F.over(c,F.lay(OUT+l+'.png'))
F.img(c).save('/home/claude/ri/bass_draft.png')
