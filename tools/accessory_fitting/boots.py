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
    """per column: the bottom edge of this pant leg's cuff, carried sideways past both ends of the cuff"""
    al=leg[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; bot=np.array([np.nonzero(al[:,x])[0].max() for x in cols]); keep=bot>bot.max()-28
    line=np.full(1000,float(bot.max())); line[cols[keep].min():cols[keep].max()+1]=np.interp(np.arange(cols[keep].min(),cols[keep].max()+1),cols[keep],bot[keep]); return line
def boot_top(boot):
    al=boot[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; top=np.array([np.nonzero(al[:,x])[0].min() for x in cols]); keep=top<top.min()+14
    return np.interp(np.arange(1000),cols[keep],top[keep])
def over_boots(boot,leg):
    """Option B: pants over the boots - the boot shows only below that pant leg's cuff."""
    o=boot.copy(); o[...,3]*=(yy>=cuff_line(leg)[None,:]-3); return o
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
