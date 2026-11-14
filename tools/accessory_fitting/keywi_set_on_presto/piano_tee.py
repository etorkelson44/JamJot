# Tenuto Tee on the piano pose from Erika's layered Piano.pdf (2026-11-13 17:31 CT): her tee, sleeves, arms and keyboard, in her order.
import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; TAG='jalapeno_piano'; P=A+'avatar_instrument/'+TAG+'/'; T,B=40,110
bp=Image.open('/home/claude/pn/B02-1.png').getbbox(); ba=Image.open(P+'1_pepper_body.png').getbbox(); k=((ba[3]-ba[1])/(bp[3]-bp[1])+(ba[2]-ba[0])/(bp[2]-bp[0]))/2
M=np.float32([[k,0,ba[0]-bp[0]*k],[0,k,ba[1]-bp[1]*k]])
def piece(*blocks):
    out=None
    for b in blocks:
        a=np.asarray(Image.open(f'/home/claude/pn/B{b:02d}-1.png').convert('RGBA')).astype(np.float32)/255; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
        o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); o=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1); out=o if out is None else F.over(out,o)
    return out
def save(x,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(f'{AC}tenuto_tee/{TAG}/{name}')
for fn in os.listdir(f'{AC}tenuto_tee/{TAG}'): os.remove(f'{AC}tenuto_tee/{TAG}/{fn}')
save(piece(7,8,9,10),'tee.png'); save(piece(11,12),'sleeve_viewer_left.png'); save(piece(13),'keyboard.png'); save(piece(14),'arm_viewer_right.png'); save(piece(15,16),'sleeve_viewer_right.png'); save(piece(17),'arm_viewer_left.png')
m=json.load(open(P+'manifest.json'))
for s_ in [s_ for s_ in m['accessory_slots'] if s_.startswith('tee_')]: del m['accessory_slots'][s_]
m['accessory_slots']['shirt_over']={'after':'5_legs_feet','note':'a sleeve drawn over the shirt body, under the keyboard'}
m['accessory_slots']['tee_sleeve_7_arm_viewer_left']={'after':'7_arm_viewer_left','note':'sleeve on top of this arm'}
open(P+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
c=json.load(open(AC+'catalog.json'))
for it in c['items']:
    if it['id']=='tenuto_tee':
        it['art'][TAG]=[{'slot':'shirt','file':'tee.png'},{'slot':'shirt_over','file':'sleeve_viewer_left.png'},{'replaces':'6_keyboard','file':'keyboard.png'},
            {'replaces':'7_arm_viewer_left','file':'arm_viewer_right.png'},{'slot':'tee_sleeve_7_arm_viewer_left','file':'sleeve_viewer_right.png'},{'replaces':'8_arm_viewer_right','file':'arm_viewer_left.png'}]
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
