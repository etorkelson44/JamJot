# Señor Jalapresto, bass guitar pose: installs the pose and fits every accessory by reusing the electric guitar fittings
# (same body, legs and strumming arm); only the pieces that follow the fretting arm are rebuilt for the bass's steeper arm.
import json, os, shutil, numpy as np, cv2
from PIL import Image
R='/home/claude/jamjot/app/assets/art/'; AC=R+'accessories/'; SRC='/home/claude/ri/pose_bass_guitar/'; EG='jalapeno_electric_guitar'; BG='jalapeno_bass_guitar'; PD=R+'avatar_instrument/'+BG+'/'
def L(f): return np.asarray(Image.open(f).convert('RGBA')).astype(np.float32)/255
def W(a,f): Image.fromarray((np.clip(a,0,1)*255).round().astype('uint8')).save(f)
os.makedirs(PD,exist_ok=True)
for f in os.listdir(SRC):
    if f.endswith('.png'): shutil.copy(SRC+f,PD+f)
m=json.load(open(SRC+'manifest.json')); m['pose']='bass_guitar'
m['note']=m['note'].split(' Source:')[0]+" Source: the electric guitar pose (Guitars_Jalapresto.pdf, 2026-11-11) with Erika's bass guitar picture (new_bass_guitar.pdf, 2026-11-14) placed at a steeper angle, about 1.08x the guitar's length; the fretting arm is redrawn to reach further up the longer neck, under the bass, with its rounded end (the thumb) just above the neck's top edge; the fingertip dots and the strumming arm are on top."
for k,v in m['accessory_slots'].items():
    for a in ('after','before'):
        if v.get(a)=='7_guitar': v[a]='7_bass_guitar'
open(PD+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
def axis_of(arm,S,r0=20,r1=140):
    ys,xs=np.nonzero(arm[...,3]>0.5); d=np.hypot(xs-S[0],ys-S[1]); k=(d>r0)&(d<r1); p=np.stack([xs[k],ys[k]],1).astype(float); c=p.mean(0); u=np.linalg.svd(p-c)[2][0]; return u if u[0]>0 else -u
c=json.load(open(AC+'catalog.json')); S=np.array((535.0,612.7)); gy,gx=np.mgrid[0:1000,0:1000]
garm=L(R+f'avatar_instrument/{EG}/6_fret_arm.png'); barm=L(PD+'6_fret_arm.png'); ug=axis_of(garm,S); ub=axis_of(barm,S)
def reach(arm,u):   # how far the straight part of the arm runs from the shoulder
    ys,xs=np.nonzero(arm[...,3]>0.5); t=(xs-S[0])*u[0]+(ys-S[1])*u[1]; n=np.abs(-(xs-S[0])*u[1]+(ys-S[1])*u[0]); return t[n<6].max()
for it in c['items']:
    a=it.get('art',{}).get(EG)
    if not a: continue
    i=it['id']; d0=f'{AC}{i}/{EG}/'; d1=f'{AC}{i}/{BG}/'; shutil.rmtree(d1,ignore_errors=True); shutil.copytree(d0,d1); pcs=json.loads(json.dumps(a))
    if i=='black_tuxedo':
        # the fretting arm and its sleeve sit behind the body, as on the guitars; the sleeve is turned and stretched to lie along the bass arm, ending the same distance short of the hand
        W(barm,d1+'1_fret_arm.png'); sv=L(d0+'2_fret_sleeve.png'); ys,xs=np.nonzero(sv[...,3]>0.5); t=(xs-S[0])*ug[0]+(ys-S[1])*ug[1]; fx=(reach(barm,ub)-(reach(garm,ug)-t.max()))/t.max()
        ng=np.array((-ug[1],ug[0])); nb=np.array((-ub[1],ub[0])); A=np.stack([ub*fx,nb],1)@np.stack([ug,ng],0); M=np.float32(np.concatenate([A,(S-A@S)[:,None]],1))
        pm=np.concatenate([sv[...,:3]*sv[...,3:],sv[...,3:]],-1); o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_CUBIC); al=np.maximum(o[...,3:],1e-6); W(np.concatenate([o[...,:3]/al,o[...,3:]],-1),d1+'2_fret_sleeve.png')
        pcs=[p for p in pcs if p.get('replaces') not in ('7_guitar','8_fingertips')]
        for f in ('guitar.png','fingertips.png'): os.remove(d1+f)
    if i=='tenuto_tee':
        # the fretting arm comes out from under its sleeve and passes in front of the bass
        sv=L(d0+'sleeve_6_fret_arm.png')[40:1040]; ta=L(d0+'tee.png')[40:1040][...,3]>0.5;   # tee pieces are 1150 tall (40 above, 110 below)
        ys,xs=np.nonzero(sv[...,3]>0.5); T=np.array((xs.max(),ys[xs.argmax()]),float)
        inside=cv2.erode((sv[...,3]>0.5).astype(np.uint8),np.ones((5,5),np.uint8))>0; near=np.hypot(gx-S[0],gy-S[1])<np.hypot(*(T-S))+12; arm=barm.copy(); arm[...,3]*=(~((inside|ta)&near)).astype(np.float32); full=np.zeros((1150,1000,4),np.float32); full[40:1040]=arm; W(full,d1+'arm_6_fret_arm.png')
        # the bass's upper horn reaches this sleeve, so the whole sleeve stays behind the bass (on the guitars the part beside the shirt is drawn over the instrument)
        pcs=[p for p in pcs if p['file']!='sleeve_6_fret_arm_beside_shirt.png']; os.remove(d1+'sleeve_6_fret_arm_beside_shirt.png')
    it['art'][BG]=pcs
# frames (the taller canvas some hats need) are the same as the electric guitar's
for it in c['items']:
    for k,v in it.items():
        if k!='art' and isinstance(v,dict) and EG in v: v[BG]=json.loads(json.dumps(v[EG]))
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
# electric guitar: the tuxedo keeps its own copy of the fingertips, so it gets the nudged ones too
shutil.copy(R+f'avatar_instrument/{EG}/8_fingertips.png',f'{AC}black_tuxedo/{EG}/fingertips.png')
