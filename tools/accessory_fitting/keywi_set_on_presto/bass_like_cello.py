# Double bass tee, built the way Erika set the cello: her tee, her small bow-arm sleeve behind his body in the same place
# on the shirt as on the cello, the bow arm's shoulder-to-elbow part hidden behind it, forearm and hand on top.
import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; T,B=40,110; CT=AC+'tenuto_tee/jalapeno_cello/'; TAG='jalapeno_double_bass'; P=A+'avatar_instrument/'+TAG+'/'
m=json.load(open(P+'manifest.json')); body=[l for l in m['layers'] if 'body' in l][0]
cb=Image.open(A+'avatar_instrument/jalapeno_cello/1_pepper_body.png').getbbox(); bb=Image.open(P+body+'.png').getbbox(); dx,dy=bb[0]-cb[0],bb[1]-cb[1]
def warp(a,M):
    pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1); o=cv2.warpAffine(pm,np.float32(M),(1000,1000),flags=cv2.INTER_LINEAR); al=np.maximum(o[...,3:],1e-6); return np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
def segd(Pp,Q):
    gy,gx=np.mgrid[0:1000,0:1000].astype(np.float32); v=Q-Pp; t=np.clip(((gx-Pp[0])*v[0]+(gy-Pp[1])*v[1])/(v@v),0,1); return np.hypot(gx-(Pp[0]+t*v[0]),gy-(Pp[1]+t*v[1]))
tee=warp(F.lay(CT+'tee.png')[40:1040],[[1,0,dx],[0,1,dy]])
sl0=F.lay(CT+'sleeve_bow_arm.png')[40:1040]; _ys,_xs=np.nonzero(sl0[...,3]>0.5); x0,x1=_xs.min(),_xs.max(); DROP=7
ta=tee[...,3]>0.5; need=max(max(0,(np.nonzero(ta[y+DROP+dy])[0].min()+9)-(x1+dx)) for y in range(_ys.min(),_ys.max()+1))   # how far the right edge must move to be under the shirt
kx=(x1-x0+need)/(x1-x0); sleeve=warp(sl0,[[kx,0,dx+x0-kx*x0],[0,1,dy+DROP]]); print('sleeve lowered',DROP,'right edge moved',need)
S,E=np.array((351.,542.)),np.array((278.,575.)); arm=F.lay(P+'10_right_arm.png'); ys,xs=np.nonzero(arm[...,3]>0.5); H=np.array([xs[ys>ys.max()-30].mean(),ys.max()-25.0])
# bow arm redrawn cleanly: upper arm (behind the sleeve) from the shoulder to an elbow just past the sleeve's outer edge;
# forearm as one even line from that elbow to the hand, on top of sleeve, shirt and bow; the hand itself is the original
gy,gx=np.mgrid[0:1000,0:1000]; al=arm[...,3]>0.5; col=np.median(arm[al][:,:3],0); w=2*cv2.distanceTransform((al&~(segd(E,H)<=segd(S,E))).astype(np.uint8),cv2.DIST_L2,5).max()   # the upper arm's own line width
sy,sx=np.nonzero(sleeve[...,3]>0.5); E2=np.array([sx.min()-9.0,(sy.min()+sy.max())/2+2])
fore=segd(E,H)<=segd(S,E); d0=(H-E)/np.hypot(*(H-E)); along=(gx-E[0])*d0[0]+(gy-E[1])*d0[1]; L0=np.hypot(*(H-E))
# where the fingers branch off the original forearm: the last place the arm is still a single line
perp=-(gx-E[0])*d0[1]+(gy-E[1])*d0[0]; a_=np.round(along[al&fore]).astype(int); p_=perp[al&fore]
cut=next(t for t in range(20,int(a_.max())) if (lambda v: len(v) and v.max()-v.min()>w*1.6)(p_[a_==t]))-3      # walking from the elbow: where the arm first widens into fingers
band=al&fore&(np.abs(along-cut)<2.5); wrist=np.array([gx[band].mean(),gy[band].mean()]); hand=arm.copy(); hand[...,3]*=(fore&(along>cut-1)).astype(np.float32); print('hand joins at',wrist)
def line(p,q):
    S4=4; im=np.zeros((4000,4000),np.uint8); cv2.line(im,tuple(np.round(p*S4).astype(int)),tuple(np.round(q*S4).astype(int)),255,int(round(w*S4)),cv2.LINE_AA)
    for r in (p,q): cv2.circle(im,tuple(np.round(r*S4).astype(int)),int(round(w*S4/2)),255,-1,cv2.LINE_AA)
    o=np.zeros((1000,1000,4),np.float32); o[...,:3]=col; o[...,3]=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA)/255; return o
upper_arm=line(S,E2); arm=F.over(line(E2,wrist),hand); print('elbow',E,'->',E2,'arm width',w)
d=f'{AC}tenuto_tee/{TAG}/'
for fn in os.listdir(d): os.remove(d+fn)
def save(x,name):
    cc=np.zeros((1000+T+B,1000,4),np.float32); cc[T:T+1000]=x; Image.fromarray((np.clip(cc,0,1)*255).round().astype('uint8')).save(d+name)
save(tee,'tee.png'); save(sleeve,'sleeve_bow_arm.png'); save(arm,'bow_forearm_hand.png'); save(upper_arm,'bow_upper_arm.png')
for s_ in [s_ for s_ in m['accessory_slots'] if s_.startswith('tee_') or s_=='shirt_sleeves']: del m['accessory_slots'][s_]
m['accessory_slots'].setdefault('behind_body',{'before':body}); open(P+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
c_=json.load(open(AC+'catalog.json'))
[i for i in c_['items'] if i['id']=='tenuto_tee'][0]['art'][TAG]=[{'slot':'behind_body','file':'bow_upper_arm.png'},{'slot':'behind_body','file':'sleeve_bow_arm.png'},{'slot':'shirt','file':'tee.png'},{'replaces':'10_right_arm','file':'bow_forearm_hand.png'}]
open(AC+'catalog.json','w').write(json.dumps(c_,indent=2,ensure_ascii=False)+'\n')
