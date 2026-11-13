import numpy as np, cv2, json, os
from PIL import Image
A='/home/claude/jamjot/app/assets/art/'; P=A+'avatar_pose/kiwi_standing/'
def lay(p): return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32)/255
def over(a,b):
    aa,ba=a[...,3:],b[...,3:]; oa=ba+aa*(1-ba); oc=(b[...,:3]*ba+a[...,:3]*aa*(1-ba))/np.maximum(oa,1e-6); return np.concatenate([oc,oa],-1)
hb=(429,253,1510,1302); ab=(157,90,807,721)
S=((ab[2]-ab[0])/(hb[2]-hb[0])+(ab[3]-ab[1])/(hb[3]-hb[1]))/2; TX=(ab[0]+ab[2])/2-S*(hb[0]+hb[2])/2; TY=(ab[1]+ab[3])/2-S*(hb[1]+hb[3])/2
M=np.float32([[S,0,TX],[0,S,TY]])
def w(*names):
    out=None
    for n in names:
        im=lay(f'/home/claude/kw/{n}.png'); x=cv2.warpAffine(np.concatenate([im[...,:3]*im[...,3:],im[...,3:]],-1),M,(1000,1000),flags=cv2.INTER_AREA); a=np.maximum(x[...,3:],1e-6)
        x=np.concatenate([np.clip(x[...,:3]/a,0,1),x[...,3:]],-1); out=x if out is None else over(out,x)
    return out
PIECES={'hat':w('piece_X57'),'glasses':w('piece_X50','piece_X52'),'tee_body':w('piece_X26'),'tee_sleeve_left':w('piece_X32'),'tee_sleeve_right':w('piece_X38'),'tee_logo':w('piece_X53'),
        'soles':w('sub_X39'),'straps':w('sub_X42','sub_X45','sub_X46'),'pants':w('sub_X47'),'her_legs':w('sub_X41'),'her_full':w('full')}
if __name__=='__main__':
    print('S',round(S,4),round(TX,1),round(TY,1))
    L={l:lay(P+l+'.png') for l in json.load(open(P+'manifest.json'))['layers']}
    order=[L['1_body'],L['2_eyes_brows'],L['3_mouth'],PIECES['glasses'],PIECES['soles'],L['4_legs_feet'],PIECES['straps'],L['5_arm_viewer_left'],L['6_arm_viewer_right'],
           PIECES['tee_body'],PIECES['tee_sleeve_left'],PIECES['tee_sleeve_right'],PIECES['tee_logo'],PIECES['pants'],PIECES['hat']]
    c=np.ones((1000,1000,4),np.float32)
    for o in order: c=over(c,o)
    h=over(np.ones((1000,1000,4),np.float32),PIECES['her_full'])
    Image.fromarray((c[...,:3]*255).astype('uint8')).save('/home/claude/kw/mine.png'); Image.fromarray((h[...,:3]*255).astype('uint8')).save('/home/claude/kw/hers.png')
    diff=np.abs(c[...,:3]-h[...,:3]).max(-1)>0.25; print('differing px',int(diff.sum()))
    ys,xs=np.nonzero(diff); 
    if len(xs): print('diff bbox',xs.min(),ys.min(),xs.max(),ys.max())
    Image.fromarray((diff*255).astype('uint8')).save('/home/claude/kw/diff.png')
    V=Image.new('RGB',(2000,1000),'white'); V.paste(Image.open('/home/claude/kw/hers.png'),(0,0)); V.paste(Image.open('/home/claude/kw/mine.png'),(1000,0)); V.save('/home/claude/kw/Keywi_set_yours_vs_app_build.png')
    for k in ('her_legs',):
        a=PIECES[k][...,3]>0.5; b=L['4_legs_feet'][...,3]>0.5; print('legs same px share',(a&b).sum()/max(1,(a|b).sum()))
