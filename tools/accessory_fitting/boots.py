import cv2
import numpy as np, json
from PIL import Image
import sys; sys.path.insert(0,'/home/claude/pp'); import fit2 as F
AC='/home/claude/jamjot/app/assets/art/accessories/'; AP='/home/claude/jamjot/app/assets/art/avatar_pose/kiwi_standing/'
T=40
def L1000(p):
    a=F.lay(p); return a[T:T+1000] if a.shape[0]>1000 else a
legs=L1000(AC+'jazzy_joggers/kiwi_standing/legs.png'); pants=L1000(AC+'jazzy_joggers/kiwi_standing/joggers.png')
bl=L1000(AC+'lilac_platform_boots/kiwi_standing/1_boot_viewer_left.png'); br=L1000(AC+'lilac_platform_boots/kiwi_standing/2_boot_viewer_right.png')
def profile(al,kind):
    """per column: top (min y) or bottom (max y) of a shape, extended sideways to columns it does not reach"""
    cols=np.nonzero(al.any(0))[0]; out=np.zeros(1000)
    v=np.array([ (np.nonzero(al[:,x])[0].min() if kind=='top' else np.nonzero(al[:,x])[0].max()) for x in cols])
    out[:]=np.interp(np.arange(1000),cols,v); return out
_m,_leg,_a=F.legs_of('avatar_pose/kiwi_standing'); PA,PB,_cr,_inf,_cuff=F.joggers_two_legs(_a,.22,702); PA,PB=PA[:1000],PB[:1000]
yy=np.arange(1000)[:,None]
def cuff_line(leg):
    """Per column: where the boot may start showing. Under the flat bottom edge of this pant leg's cuff it is that edge;
    everywhere else (rounded cuff corners, the sides of the pant leg, columns the pants do not reach) it is the cuff's
    lowest point, so no boot shows beside the pants above their bottom edge."""
    al=leg[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; bot=np.array([np.nonzero(al[:,x])[0].max() for x in cols]).astype(float)
    flat=np.abs(np.gradient(bot))<1.0; i=int(bot.argmax()); lo=hi=None
    # the longest run of gently sloping columns: the cuff's bottom edge
    runs=[]; st=None
    for k,f in enumerate(flat):
        if f and st is None: st=k
        if (not f or k==len(flat)-1) and st is not None: runs.append((st,k if not f else k+1)); st=None
    lo,hi=max(runs,key=lambda r:r[1]-r[0]); lo,hi=lo+8,hi-8   # stay clear of the rounded cuff corners
    line=np.full(1000,float(bot.max())); line[cols[lo]:cols[hi-1]+1]=bot[lo:hi]; return line
def boot_top(boot):
    al=boot[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; top=np.array([np.nonzero(al[:,x])[0].min() for x in cols]); keep=top<top.min()+14
    return np.interp(np.arange(1000),cols[keep],top[keep])
def over_boots(boot,leg):
    """Option B: pants over the boots - the boot shows only below that pant leg's cuff."""
    o=boot.copy(); keep=(yy>=cuff_line(leg)[None,:]-2)&(boot[...,3]>0.5)
    # Grade the cut: instead of a step beside the cuff, the boot's edge runs in a straight slope from the cuff's bottom
    # corner out to the curve of the boot (convex hull of what is kept, still inside the boot's own shape).
    pts=cv2.findNonZero(keep.astype(np.uint8)); hull=np.zeros(keep.shape,np.uint8); cv2.fillConvexPoly(hull,cv2.convexHull(pts),1)
    m=cv2.GaussianBlur(hull.astype(np.float32),(0,0),0.8); o[...,3]*=np.clip(m*1.6-0.3,0,1); return o
def shaft(boot):
    al=boot[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; top=np.array([np.nonzero(al[:,x])[0].min() for x in cols]); keep=top<top.min()+14; return cols[keep].mean(), float(top.min())
def tucked():
    """Option A: pants tucked in - each pant leg runs into the top of its boot and stops there."""
    (xl,yl),(xr,yr)=shaft(bl),shaft(br); TA,TB,*_=F.joggers_two_legs(_a,.22,702,ends=(xl,xr,max(yl,yr)+26))
    return F.over(TA[:1000],TB[:1000])
if __name__=="__main__":
  pass
base=[F.lay(AP+f'{l}.png') for l in ['1_body','2_eyes_brows','3_mouth']]; arms=[F.lay(AP+f'{l}.png') for l in ['5_arm_viewer_left','6_arm_viewer_right']]
now=F.flat(base+[legs,bl,br]+arms+[pants]); A=F.flat(base+[legs]+arms+[tucked(),bl,br]); B=F.flat(base+[legs,over_boots(bl,PA),over_boots(br,PB)]+arms+[pants])
from PIL import ImageDraw, ImageFont
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',24)
W=Image.new('RGB',(3*640,760),'white'); d=ImageDraw.Draw(W)
for i,(n,c) in enumerate((('Now',now),('A: pants tucked into the boots',A),('B: pants over the boots',B))):
    W.paste(F.img(c).crop((330,640,650,1000)).resize((640,720),Image.LANCZOS),(i*640,40)); d.text((i*640+10,6),n,fill=(60,40,110),font=f)
W.save('Keywi_joggers_boots_options.png')
