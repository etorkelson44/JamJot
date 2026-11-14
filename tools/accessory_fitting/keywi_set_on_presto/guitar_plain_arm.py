import os, sys, shutil, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; BK='/home/claude/th/bk_guitar/'; os.makedirs(BK,exist_ok=True); gy,gx=np.mgrid[0:1000,0:1000]
for pose in ['acoustic_guitar','electric_guitar','ukulele']:
    p=A+f'avatar_instrument/jalapeno_{pose}/9_strum_arm_hand.png'; b=BK+pose+'.png'
    if not os.path.exists(b): shutil.copy(p,b)
    arm=F.lay(b); al=arm[...,3]>0.5; ys,xs=np.nonzero(al); body=F.lay(A+f'avatar_instrument/jalapeno_{pose}/1_pepper_body.png')[...,3]>0.5
    w=2*cv2.distanceTransform(al.astype(np.uint8),cv2.DIST_L2,5)[ys.min():ys.min()+30].max(); top=np.array([xs[ys<ys.min()+6].mean(),ys.min()+w/2])
    left=xs<xs.min()+30; ye=ys[left].max(); El=np.array([xs[left&(ys>ye-4)].min()+w/2, ye-w/2])           # the elbow: the bottom-left corner where the upper arm meets the forearm
    edge=np.nonzero(body[int(top[1])])[0].min(); S2=np.array([max(top[0],edge+w/2+4),top[1]]); print(pose,'arm top',top,'-> new top',S2,'elbow',El,'width',w)
    arm[...,3]*=(((gy>El[1]-w/2)|(gx>El[0]+30))&~((gx<El[0]-w/2)&(gy<El[1]+w))).astype(np.float32); S4=4; im=np.zeros((4000,4000),np.uint8); cv2.line(im,tuple(np.round(S2*S4).astype(int)),tuple(np.round(El*S4).astype(int)),255,int(round(w*S4)),cv2.LINE_AA)
    for q in (S2,El): cv2.circle(im,tuple(np.round(q*S4).astype(int)),int(round(w*S4/2)),255,-1,cv2.LINE_AA)
    up=np.zeros((1000,1000,4),np.float32); up[...,3]=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA)/255
    Image.fromarray((np.clip(F.over(up,arm),0,1)*255).round().astype('uint8')).save(p)
