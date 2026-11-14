# Tenuto Tee on the violin and viola poses from Erika's layered violin_blue_.pdf (2026-11-13 17:37 CT).
import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; T,B=40,110; V=A+'avatar_instrument/jalapeno_violin/'
bp=Image.open('/home/claude/vn/B02-1.png').getbbox(); ba=Image.open(V+'1_pepper_body.png').getbbox(); k=((ba[3]-ba[1])/(bp[3]-bp[1])+(ba[2]-ba[0])/(bp[2]-bp[0]))/2
M=np.float32([[k,0,ba[0]-bp[0]*k],[0,k,ba[1]-bp[1]*k]])
def piece(b,M2=None):
    a=np.asarray(Image.open(f'/home/claude/vn/B{b:02d}-1.png').convert('RGBA')).astype(np.float32)/255; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
    Mm=M if M2 is None else (M2@np.vstack([M,[0,0,1]]))[:2].astype(np.float32)
    o=cv2.warpAffine(pm,Mm,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); return np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
def save(x,tag,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(f'{AC}tenuto_tee/{tag}/{name}')
def neck_y(pose,layer,x):
    a=F.lay(A+f'avatar_instrument/jalapeno_{pose}/{layer}.png')[...,3]>0.5; ys=np.nonzero(a[:,int(x)])[0]; return (ys.min()+ys.max())/2
tee,armL,bow,armR=piece(4),piece(6),piece(9),piece(10)
# viola: same shirt and bow arm; the left arm is turned about its shoulder so the hand lands on the viola's neck
ys,xs=np.nonzero(armL[...,3]>0.5); hand=np.array([xs[ys<ys.min()+25].mean(),ys.min()+12.0]); i=np.argmin(xs+0*ys); sh=np.array([xs.min()+4.0,ys[xs<xs.min()+8].mean()])
dy=neck_y('viola','6_viola',hand[0])-neck_y('violin','4_violin',hand[0]); new=hand+np.array([0,dy]); v0,v1=hand-sh,new-sh
sc=np.hypot(*v1)/np.hypot(*v0); ang=np.arctan2(v1[1],v1[0])-np.arctan2(v0[1],v0[0]); c_,s_=np.cos(ang)*sc,np.sin(ang)*sc
R=np.array([[c_,-s_,sh[0]-(c_*sh[0]-s_*sh[1])],[s_,c_,sh[1]-(s_*sh[0]+c_*sh[1])],[0,0,1]]); print('viola hand moves',dy,'px; arm turned',np.degrees(ang),'deg, scale',sc)
armL_viola=piece(6,R)
c=json.load(open(AC+'catalog.json')); tee_item=[i for i in c['items'] if i['id']=='tenuto_tee'][0]
for pose,arms in (('violin',{'left':'5_left_arm_hand','bow':'8_bow','right':'9_right_arm_bow_hand'}),('viola',{'left':'4_left_arm_hand','bow':'9_bow','right':'10_right_forearm_bow_hand','empty':'5_right_upper_arm'})):
    tag='jalapeno_'+pose; d=f'{AC}tenuto_tee/{tag}/'
    for fn in os.listdir(d): os.remove(d+fn)
    save(tee,tag,'tee.png'); save(armL if pose=='violin' else armL_viola,tag,'arm_left.png'); save(bow,tag,'bow.png'); save(armR,tag,'arm_right.png')
    art=[{'slot':'shirt','file':'tee.png'},{'replaces':arms['left'],'file':'arm_left.png'},{'replaces':arms['bow'],'file':'bow.png'},{'replaces':arms['right'],'file':'arm_right.png'}]
    if 'empty' in arms: save(tee*0,tag,'empty.png'); art.append({'replaces':arms['empty'],'file':'empty.png'})
    tee_item['art'][tag]=art
    p=A+f'avatar_instrument/{tag}/manifest.json'; m=json.load(open(p))
    for s2 in [s2 for s2 in m['accessory_slots'] if s2.startswith('tee_') or s2=='shirt_sleeves']: del m['accessory_slots'][s2]
    open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
