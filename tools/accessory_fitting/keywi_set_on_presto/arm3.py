import sys, json, os, shutil, numpy as np, cv2
sys.path.insert(0,'/home/claude/vn'); sys.path.insert(0,'/home/claude/pp')
import fit2 as F
from PIL import Image
exec(open('/home/claude/vn/vv_tee.py').read().split("tee,armL,bow,armR=")[0])
from arm_clean import hand_of, segd, joints
BK='/home/claude/vn/bk/'; os.makedirs(BK,exist_ok=True)
def orig(path):
    b=BK+path.replace('/','__')
    if not os.path.exists(b): shutil.copy(path,b)
    return b
def strokes(lines,w,color):
    S4=4; im=np.zeros((4000,4000),np.uint8)
    for pts,ww in lines:
        q=np.round(np.array(pts)*S4).astype(np.int32); cv2.polylines(im,[q],False,255,int(round(ww*S4)),cv2.LINE_AA)
        for p in q: cv2.circle(im,tuple(int(v) for v in p),int(round(ww*S4/2)),255,-1,cv2.LINE_AA)
    o=np.zeros((1000,1000,4),np.float32); o[...,:3]=color; o[...,3]=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA)/255; return o
def arm(a,target,reach=18,finger=36,spread=30,up=-98):
    """One even line shoulder -> elbow -> hand, then three separate fingers fanning out from the end of the forearm, in line with it."""
    S,E,H=joints(a); al=a[...,3]>0.5; fore=segd(E,H)<=segd(S,E); color=np.median(a[al][:,:3],0); w=2*cv2.distanceTransform((al&~fore).astype(np.uint8),cv2.DIST_L2,5).max()
    S=S-(E-S)/np.hypot(*(E-S))*reach; d=(target-E)/np.hypot(*(target-E)); th=np.arctan2(d[1],d[0]); palm=target-d*4
    lines=[([S,E,palm],w)]+[([palm,palm+finger*np.array([np.cos(th+np.radians(g)),np.sin(th+np.radians(g))])],w*0.72) for g in (-spread,0,spread)]
    lines=[lines[0]]+[([palm,palm+finger*np.array([np.cos(np.radians(up+g)),np.sin(np.radians(up+g))])],w*0.72) for g in (-spread,0,spread)]   # fingers reach straight over the neck
    return strokes(lines,w,color),(S,E,target,w)
def put(x,path): Image.fromarray((np.clip(x,0,1)*255).round().astype('uint8')).save(path)
VD=A+'avatar_instrument/jalapeno_violin/'; LD=A+'avatar_instrument/jalapeno_viola/'
# --- manifests: arms attach under the instrument and under clothing ---
p=VD+'manifest.json'; m=json.load(open(p)); L=[l for l in m['layers'] if l not in('5_left_arm_hand','5b_right_upper_arm')]; i=L.index('4_violin'); L[i:i]=['5_left_arm_hand','5b_right_upper_arm']; m['layers']=L
for s2 in ('clothing_lower','shirt'): m['accessory_slots'][s2]={'after':'5b_right_upper_arm','note':'clothes cover where the arms join the body; under the instrument'}
open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
p=LD+'manifest.json'; m=json.load(open(p))
for s2 in ('clothing_lower','shirt'): m['accessory_slots'][s2]={'after':'5_right_upper_arm','note':'clothes cover where the arms join the body; under the instrument'}
open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
# --- violin bow arm: upper arm on its own layer under the violin and clothes (as the viola already has) ---
ra=F.lay(orig(VD+'9_right_arm_bow_hand.png')); S_,E_,Hh=np.array((367.,603.)),np.array((314.,623.)),np.array((410.,650.)); fore=segd(E_,Hh)<=segd(S_,E_)
u=ra.copy(); u[...,3]*=~fore; f=ra.copy(); f[...,3]*=fore; put(u,VD+'5b_right_upper_arm.png'); put(f,VD+'9_right_arm_bow_hand.png')
# --- left arms ---
pv=F.lay(orig(VD+'5_left_arm_hand.png')) if not os.path.exists('/home/claude/vn/plain_violin_arm_before.png') else F.lay('/home/claude/vn/plain_violin_arm_before.png')
tv=hand_of(pv)+np.array([-24.0,-2.0]); x,(S,E,Tg,w)=arm(pv,tv); put(x,VD+'5_left_arm_hand.png')
pl=F.lay(orig(LD+'4_left_arm_hand.png')); tl=hand_of(pl)+np.array([0.0,6.0]); x,_=arm(pl,tl); put(x,LD+'4_left_arm_hand.png')
armL=piece(6); tee=piece(4); armR=piece(10)
x,_=arm(armL,tv,reach=6); save(x,'jalapeno_violin','arm_left.png'); x,_=arm(armL,tl,reach=6); save(x,'jalapeno_viola','arm_left.png')
# bow arm with the tee: comes out from under the sleeve instead of sitting on top of it
ta=tee[...,3]>0.5; rows=np.nonzero(ta.any(1))[0]; seam=np.nonzero(ta[rows.max()-20])[0].min()        # left edge of the shirt body
hide=cv2.dilate((ta&(np.arange(1000)[None,:]<seam)).astype(np.uint8),np.ones((3,3),np.uint8)).astype(np.float32); ar=armR.copy(); ar[...,3]*=1-hide
for tag in ('jalapeno_violin','jalapeno_viola'): save(ar,tag,'arm_right.png'); save(tee*0,tag,'empty.png')
c=json.load(open(AC+'catalog.json')); t=[i for i in c['items'] if i['id']=='tenuto_tee'][0]
t['art']['jalapeno_violin']=[q for q in t['art']['jalapeno_violin'] if q.get('replaces')!='5b_right_upper_arm']+[{'replaces':'5b_right_upper_arm','file':'empty.png'}]
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n'); print('seam',seam)
