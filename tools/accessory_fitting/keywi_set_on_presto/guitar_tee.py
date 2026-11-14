# Tenuto Tee on the guitars and ukulele (Erika's notes 2026-11-14 14:30 CT): her piano sleeves at the shirt's top corners,
# nudged out; strumming-side sleeve drawn over the guitar where they overlap; upper arms hidden behind the sleeves with no gap.
import json, os, sys, numpy as np, cv2
os.chdir('/home/claude/th'); sys.path.insert(0,'/home/claude/pp'); sys.path.insert(0,'/home/claude/th')
import fit2 as F, std, poses_top as PT
def quad(pts,s,ink=5.2):
    S4=4; hull=cv2.convexHull(np.round(np.array(pts)*S4).astype(np.int32)); im=np.zeros((4000,4000),np.uint8); cv2.fillPoly(im,[hull],255); ln=np.zeros_like(im); cv2.polylines(ln,[hull],True,255,int(round(ink*s*S4)),cv2.LINE_AA)
    f=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA).astype(np.float32)/255; k=cv2.resize(ln,(1000,1000),interpolation=cv2.INTER_AREA).astype(np.float32)/255
    o=np.zeros((1000,1000,4),np.float32); o[...,:3]=PT.BLUE; o[...,3]=f; l=np.zeros_like(o); l[...,3]=k; return F.over(o,l), np.maximum(f,k)
from PIL import Image
A=F.AR; AC=A+'accessories/'; PD=AC+'tenuto_tee/jalapeno_piano/'; OUT=10.0
def corners(ta):
    ys,xs=np.nonzero(ta); i={'L':np.argmin(xs+ys),'R':np.argmin(-xs+ys)}; return {k:np.array((xs[v],ys[v]),float) for k,v in i.items()},(xs.min()+xs.max())/2
ptee=F.lay(PD+'tee.png')[40:1040]; pc,_=corners(ptee[...,3]>0.5); SRC={}
for side,fn in (('L','sleeve_viewer_left.png'),('R','sleeve_viewer_right.png')):
    a=F.lay(PD+fn)[40:1040]; ys,xs=np.nonzero(a[...,3]>0.5); pts=np.stack([xs,ys],1).astype(float); an=pc[side]; SRC[side]=(a,an,pts[np.argmax(np.hypot(*(pts-an).T))])
def place(side,P0,T):
    a,an,tip=SRC[side]; v0=tip-an; v1=T-P0; sc=np.clip(np.hypot(*v1)/np.hypot(*v0),0.8,1.0); ang=np.arctan2(v1[1],v1[0])-np.arctan2(v0[1],v0[0]); c,s=np.cos(ang)*sc,np.sin(ang)*sc
    M=np.float32([[c,-s,P0[0]-(c*an[0]-s*an[1])],[s,c,P0[1]-(s*an[0]+c*an[1])]]); pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1); o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_LINEAR); al=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
c=json.load(open(AC+'catalog.json')); tee_item=[i for i in c['items'] if i['id']=='tenuto_tee'][0]; gy,gx=np.mgrid[0:1000,0:1000]
for pose in ['acoustic_guitar','electric_guitar','ukulele']:
    arms=PT.ARMS[pose]; tag='jalapeno_'+pose; pth=A+'avatar_instrument/'+tag+'/'; m=json.load(open(pth+'manifest.json')); body=[l for l in m['layers'] if 'body' in l][0]; leg=[l for l in m['layers'] if 'legs' in l][0]; inst=[l for l in m['layers'] if any(w in l for w in ('guitar','ukulele'))][0]
    bb=Image.open(pth+body+'.png').getbbox(); tee,s=PT.moved(std.P['tee'],bb); ta=tee[...,3]>0.5; cr,mid=corners(ta); d_=f'{AC}tenuto_tee/{tag}/'
    for fn in os.listdir(d_): os.remove(d_+fn)
    for k in [k for k in m['accessory_slots'] if k.startswith('tee_')]: del m['accessory_slots'][k]
    m['accessory_slots']['shirt_sleeves']={'after':leg,'note':'shirt sleeves: joined to the shirt, behind its body'}
    m['accessory_slots']['tee_arm_over']={'after':inst,'note':'the fretting arm, in front of the instrument'}; m['accessory_slots']['tee_sleeve_over']={'after':inst,'note':'the part of a sleeve that shows beside the shirt, in front of the instrument'}
    open(pth+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
    PT.save(tee,'tenuto_tee',tag,'tee.png'); PT.save(tee*0,'tenuto_tee',tag,'empty.png'); pieces=[]
    for layer,(S_,E_) in arms.items():
        S_,E_=np.array(S_,float),np.array(E_,float); side='L' if S_[0]<mid else 'R'; out=-1.0 if side=='L' else 1.0; P0=cr[side]+np.array((out*(OUT-6),4.0))
        # triangle sleeve in Erika's style: its inner edge lies flat along the shirt's side, 4px inside it, so that border is just under the shirt body
        ys_t,xs_t=np.nonzero(ta); top=cr[side]; bi=np.argmin(xs_t-ys_t) if side=='L' else np.argmax(xs_t+ys_t); bot=np.array((xs_t[bi],ys_t[bi]),float); e=(bot-top)/np.hypot(*(bot-top))
        inn=np.array((-out,0.0)); B0=top+e*8*s+inn*4*s; B1=top+e*100*s+inn*4*s; d=(E_-S_)/np.hypot(*(E_-S_)); nrm=np.array((e[1],-e[0])); nrm=nrm if nrm[0]*out>0 else -nrm
        apex=(B0+B1)/2+nrm*70*s+e*(18*s if side=='L' else 30*s); sv,_m=quad([B0,B1,apex+e*1.0,apex-e*1.0],s); T=apex; f=f'sleeve_{layer}.png'; PT.save(sv,'tenuto_tee',tag,f); pieces.append({'slot':'shirt_sleeves','file':f})
        beside=sv.copy(); beside[...,3]*=(~ta).astype(np.float32); f2=f'sleeve_{layer}_beside_shirt.png'; PT.save(beside,'tenuto_tee',tag,f2); pieces.append({'slot':'tee_sleeve_over','file':f2})
        # upper arm behind the sleeve: hidden where it is under the sleeve (just inside its outline, so no gap) or still over the shirt body
        arm=F.lay(pth+layer+'.png'); inside=cv2.erode((sv[...,3]>0.5).astype(np.uint8),np.ones((5,5),np.uint8))>0; near=np.hypot(gx-S_[0],gy-S_[1])<np.hypot(*(T-S_))+12
        arm[...,3]*=(~((inside|ta)&near)).astype(np.float32); f3=f'arm_{layer}.png'; PT.save(arm,'tenuto_tee',tag,f3)
        if 'strum' in layer:
            # strumming arm: its short upper part is redrawn as one clean line from under the sleeve down to the elbow, in front of the guitar
            arm=F.lay('/home/claude/th/bk_guitar/'+pose+'.png'); al=arm[...,3]>0.5; ys_,xs_=np.nonzero(al); w=2*cv2.distanceTransform(al.astype(np.uint8),cv2.DIST_L2,5)[ys_.min():ys_.min()+30].max()
            left=xs_<xs_.min()+30; ye=ys_[left].max(); El=np.array([xs_[left&(ys_>ye-4)].min()+w/2, ye-w/2])        # the elbow of the original arm
            arm[...,3]*=(((gy>El[1]-w/2)|(gx>El[0]+30))&~((gx<El[0]-w/2)&(gy<El[1]+w))).astype(np.float32)
            C=B1-inn*(4*s+w/2+3)-e*14*s; S4=4; im=np.zeros((4000,4000),np.uint8); cv2.line(im,tuple(np.round(C*S4).astype(int)),tuple(np.round(El*S4).astype(int)),255,int(round(w*S4)),cv2.LINE_AA)
            up_=np.zeros((1000,1000,4),np.float32); up_[...,3]=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA)/255
            im2=np.zeros((4000,4000),np.uint8); cv2.circle(im2,tuple(np.round(El*S4).astype(int)),int(round(w*S4/2)),255,-1,cv2.LINE_AA); up_[...,3]=np.maximum(up_[...,3],cv2.resize(im2,(1000,1000),interpolation=cv2.INTER_AREA)/255)
            PT.save(arm,'tenuto_tee',tag,f3); PT.save(up_,'tenuto_tee',tag,'strum_upper_arm.png'); pieces.insert(len(pieces)-1,{'slot':'tee_arm_over','file':'strum_upper_arm.png'}); pieces.append({'replaces':layer,'file':f3})
        elif 'fret' in layer: pieces+= [{'replaces':layer,'file':'empty.png'},{'slot':'tee_arm_over','file':f3}]
        else: pieces.append({'replaces':layer,'file':f3})
    pieces.append({'slot':'shirt','file':'tee.png'}); tee_item['art'][tag]=pieces
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
