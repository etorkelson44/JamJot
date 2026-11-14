# Tenuto Tee on the cello pose from Erika's blue_shirt_and_cello.pdf (2026-11-14 14:10 CT): her tee and her sleeve; the bow
# arm's shoulder-to-elbow part is hidden behind the sleeve, the forearm and hand stay on top of shirt, bow and cello.
import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; TAG='jalapeno_cello'; P=A+'avatar_instrument/'+TAG+'/'; T,B=40,110
bp=Image.open('/home/claude/ce/B04-1.png').getbbox(); ba=Image.open(P+'1_pepper_body.png').getbbox(); k=((ba[3]-ba[1])/(bp[3]-bp[1])+(ba[2]-ba[0])/(bp[2]-bp[0]))/2
def piece(blocks,dx=0.0):
    M=np.float32([[k,0,ba[0]-bp[0]*k+dx],[0,k,ba[1]-bp[1]*k]]); out=None
    for b in blocks:
        a=np.asarray(Image.open(f'/home/claude/ce/B{b:02d}-1.png').convert('RGBA')).astype(np.float32)/255; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
        o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); o=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1); out=o if out is None else F.over(out,o)
    return out
# her cello-and-arms picture sits a little to the right of the app's; the sleeve moves with the arm it belongs to
gb=Image.open('/home/claude/ce/B09-1.png').getbbox(); her_x=ba[0]+(gb[0]-bp[0])*k
app_x=min(Image.open(P+l+'.png').getbbox()[0] for l in ('6_left_upper_arm','7_cello','8_left_forearm_hand','9_bow','10_right_arm')); dx=app_x-her_x; print('sleeve shift',dx)
tee=piece([8]); sleeve=piece([2,3],dx)
d=f'{AC}tenuto_tee/{TAG}/'
for fn in os.listdir(d): os.remove(d+fn)
def save(x,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(d+name)
def segd(Pp,Q):
    yy,xx=np.mgrid[0:1000,0:1000].astype(np.float32); v=Q-Pp; t=np.clip(((xx-Pp[0])*v[0]+(yy-Pp[1])*v[1])/(v@v),0,1); return np.hypot(xx-(Pp[0]+t*v[0]),yy-(Pp[1]+t*v[1]))
arm=F.lay(P+'10_right_arm.png'); ys,xs=np.nonzero(arm[...,3]>0.5); E=np.array([xs.min()+7.0,ys[xs<xs.min()+10].mean()]); S=np.array([xs[ys<ys.min()+16].max()-4.0,ys.min()+7.0]); H=np.array([xs[ys>ys.max()-30].mean(),ys.max()-25.0]); print('S',S,'E',E,'H',H)
upper=(segd(S,E)<segd(E,H))&(np.arange(1000)[None,:]>E[0]+9); arm[...,3]*=(~upper).astype(np.float32)
save(tee,'tee.png'); save(sleeve,'sleeve_bow_arm.png'); save(arm,'bow_forearm_hand.png')
m=json.load(open(P+'manifest.json'))
for s_ in [s_ for s_ in m['accessory_slots'] if s_.startswith('tee_') or s_=='shirt_sleeves']: del m['accessory_slots'][s_]
m['accessory_slots'].setdefault('behind_body',{'before':'1_pepper_body'}); open(P+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n'); print(m['accessory_slots'].get('shirt'),m['accessory_slots'].get('behind_body'))
c=json.load(open(AC+'catalog.json'))
[i for i in c['items'] if i['id']=='tenuto_tee'][0]['art'][TAG]=[{'slot':'behind_body','file':'sleeve_bow_arm.png'},{'slot':'shirt','file':'tee.png'},{'replaces':'10_right_arm','file':'bow_forearm_hand.png'}]
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
