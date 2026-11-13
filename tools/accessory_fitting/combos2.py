import numpy as np, cv2, json
from PIL import Image, ImageDraw, ImageFont
import build_kw as B
from build_kw import lay, over, P
T=40; H=1000+T+110; S=B.S
def w(names,dx=0,dy=0):
    M=np.float32([[S,0,B.TX+dx],[0,S,B.TY+T+dy]]); out=None
    for n in names:
        im=lay(f'/home/claude/kw/{n}.png'); x=cv2.warpAffine(np.concatenate([im[...,:3]*im[...,3:],im[...,3:]],-1),M,(1000,H),flags=cv2.INTER_AREA); a=np.maximum(x[...,3:],1e-6)
        x=np.concatenate([np.clip(x[...,:3]/a,0,1),x[...,3:]],-1); out=x if out is None else over(out,x)
    return out
def app(l):
    c=np.zeros((H,1000,4),np.float32); c[T:T+1000]=lay(P+l+'.png'); return c
def half(a,left):
    o=a.copy(); xs=np.nonzero((a[...,3]>0.3).any(0))[0]; mid=(xs.min()+xs.max())//2
    if left: o[:,mid:,3]=0
    else: o[:,:mid,3]=0
    return o
def foot(a):  # centre-x and bottom-y of the lowest 30 rows
    ys,xs=np.nonzero(a[...,3]>0.5); b=ys.max(); m=ys>b-30; return xs[m].mean(), b
LEG_APP=app('4_legs_feet'); LEG_HER=w(['sub_X41']); SOLE=w(['sub_X39']); STRAP=w(['sub_X42','sub_X45','sub_X46'])
def sandals_on_app():
    so=np.zeros((H,1000,4),np.float32); st=so.copy()
    for left in (True,False):
        fa=foot(half(LEG_APP,left)); fh=foot(half(LEG_HER,left)); dx,dy=int(round(fa[0]-fh[0])),int(round(fa[1]-fh[1]))
        Mx=np.float32([[1,0,dx],[0,1,dy]])
        so=over(so,cv2.warpAffine(half(SOLE,left),Mx,(1000,H))); st=over(st,cv2.warpAffine(half(STRAP,left),Mx,(1000,H)))
    return so,st
PIE=dict(body=app('1_body'),eyes=app('2_eyes_brows'),mouth=app('3_mouth'),armL=app('5_arm_viewer_left'),armR=app('6_arm_viewer_right'),
         armL2=w(['piece_armL']),armR2=w(['clean_armR']),tee=w(['clean_tee']),pants=w(['sub_X47']),hat=w(['clean_hat']),glasses=w(['clean_glasses']))
def render(items):
    tee,pants,sand='tee' in items,'pants' in items,'sandals' in items
    so,st=(SOLE,STRAP) if pants else sandals_on_app()
    order=[PIE['body'],PIE['eyes'],PIE['mouth']]
    if 'glasses' in items: order.append(PIE['glasses'])
    if sand: order.append(so)
    order.append(LEG_HER if pants else LEG_APP)
    if sand: order.append(st)
    order+= [PIE['armL2'],PIE['armR2']] if tee else [PIE['armL'],PIE['armR']]
    if tee: order.append(PIE['tee'])
    if pants: order.append(PIE['pants'])
    if 'hat' in items: order.append(PIE['hat'])
    c=np.ones((H,1000,4),np.float32)
    for o in order: c=over(c,o)
    return Image.fromarray((c[...,:3]*255).astype('uint8'))
if __name__=='__main__':
    combos=[('Hat',['hat']),('Glasses',['glasses']),('Hat + glasses',['hat','glasses']),('Tee',['tee']),('Pants',['pants']),('Sandals',['sandals']),('Pants + sandals',['pants','sandals']),('Tee + pants',['tee','pants']),('Full set',['hat','glasses','tee','pants','sandals'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',26)
    cw,ch=560,int(560*H/1000); W=Image.new('RGB',(3*cw,3*(ch+40)),'white'); d=ImageDraw.Draw(W)
    for i,(nm,it) in enumerate(combos):
        x,y=(i%3)*cw,(i//3)*(ch+40); W.paste(render(it).resize((cw,ch),Image.LANCZOS),(x,y+40)); d.text((x+14,y+8),nm,fill=(60,40,110),font=f)
    W.save('/home/claude/kw/Keywi_set_combinations.png')
    render(['hat','glasses','tee','pants','sandals']).crop((80,620,560,860)).resize((960,480),Image.LANCZOS).save('/home/claude/kw/sleeve_zoom.png')
