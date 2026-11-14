import sys, json, shutil, os, numpy as np, cv2
sys.path.insert(0,'/home/claude/vn'); sys.path.insert(0,'/home/claude/pp')
import fit2 as F
from PIL import Image
exec(open('/home/claude/vn/vv_tee.py').read().split("tee,armL,bow,armR=")[0])
def hand_of(a):
    ys,xs=np.nonzero(a[...,3]>0.5); return np.array([xs[ys<ys.min()+25].mean(),ys.min()+12.0])
def segd(P,Q):
    yy,xx=np.mgrid[0:1000,0:1000].astype(np.float32); v=Q-P; t=np.clip(((xx-P[0])*v[0]+(yy-P[1])*v[1])/(v@v),0,1); return np.hypot(xx-(P[0]+t*v[0]),yy-(P[1]+t*v[1]))
def joints(a,shoulder_left=True):
    ys,xs=np.nonzero(a[...,3]>0.5); H=hand_of(a); E=np.array([xs[ys>ys.max()-10].mean(),ys.max()-5.0]); S=np.array([xs.min()+4.0,ys[xs<xs.min()+8].mean()]); return S,E,H
def rebuild(a,target,hand_r=34):
    """Upper arm kept; forearm redrawn as one even line from the elbow to the wrist; the hand turned (not resized) and moved to target."""
    S,E,H=joints(a); al=a[...,3]; fore=segd(E,H)<=segd(S,E); yy,xx=np.mgrid[0:1000,0:1000]
    w=2*cv2.distanceTransform(((al>0.5)&~fore).astype(np.uint8),cv2.DIST_L2,5).max()        # the arm's own line width
    hand=a.copy(); hand[...,3]*=fore&(np.hypot(xx-H[0],yy-H[1])<hand_r); wrist=H+(E-H)/np.hypot(*(E-H))*hand_r*0.75
    v0,v1=H-E,target-E; ang=np.degrees(np.arctan2(v1[1],v1[0])-np.arctan2(v0[1],v0[0])); M2=cv2.getRotationMatrix2D((float(H[0]),float(H[1])),-ang,1.0); M2[:,2]+=target-H
    pm=np.concatenate([hand[...,:3]*hand[...,3:],hand[...,3:]],-1); o=cv2.warpAffine(pm,M2,(1000,1000),flags=cv2.INTER_LINEAR); o=np.concatenate([o[...,:3]*0,np.clip(o[...,3:],0,1)],-1)
    nw=target+(E-target)/np.hypot(*(E-target))*hand_r*0.75; S4=4; ln=np.zeros((4000,4000),np.uint8); cv2.line(ln,tuple(np.round(E*S4).astype(int)),tuple(np.round(nw*S4).astype(int)),255,int(round(w*S4)),cv2.LINE_AA)
    cv2.circle(ln,tuple(np.round(E*S4).astype(int)),int(round(w*S4/2)),255,-1,cv2.LINE_AA); shaft=np.zeros((1000,1000,4),np.float32); shaft[...,3]=cv2.resize(ln,(1000,1000),interpolation=cv2.INTER_AREA)/255
    up=a.copy(); up[...,3]*=~fore; up[...,:3]=0; return F.over(F.over(up,shaft),o), w
if __name__=='__main__':
    V=A+'avatar_instrument/jalapeno_violin/5_left_arm_hand.png'; bk='/home/claude/vn/plain_violin_arm_before.png'
    if not os.path.exists(bk): shutil.copy(V,bk)
    plain=F.lay(bk); Hp=hand_of(plain); tv=Hp+np.array([-24.0,4.0]); new,w=rebuild(plain,tv); Image.fromarray((np.clip(new,0,1)*255).round().astype('uint8')).save(V); print('plain violin hand',Hp,'->',tv,'line width',w)
    armL=piece(6)
    for pose,tg in (('violin',tv),('viola',hand_of(F.lay(A+'avatar_instrument/jalapeno_viola/4_left_arm_hand.png')))):
        x,w=rebuild(armL,tg); save(x,'jalapeno_'+pose,'arm_left.png'); print(pose,'tee arm line width',w)
    c=json.load(open(AC+'catalog.json'))
    for it in c['items']:
        for p in it['art'].get('jalapeno_violin',[]):
            if p.get('replaces')=='5_left_arm_hand' or 'left_arm' in p.get('slot',''): print('violin left-arm art in',it['id'],p)
