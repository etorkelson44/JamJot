# Tenuto Tee on the flute pose from Erika's layered Senor_flute.pdf (2026-11-14): her tee, sleeves, arms and flute, in her order.
import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; TAG='jalapeno_flute'; P=A+'avatar_instrument/'+TAG+'/'; T,B=40,110
bp=Image.open('/home/claude/fl/B03-1.png').getbbox(); ba=Image.open(P+'1_pepper_body.png').getbbox(); k=((ba[3]-ba[1])/(bp[3]-bp[1])+(ba[2]-ba[0])/(bp[2]-bp[0]))/2
M=np.float32([[k,0,ba[0]-bp[0]*k],[0,k,ba[1]-bp[1]*k]])
def piece(*blocks):
    out=None
    for b in blocks:
        a=np.asarray(Image.open(f'/home/claude/fl/B{b:02d}-1.png').convert('RGBA')).astype(np.float32)/255; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
        o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); o=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1); out=o if out is None else F.over(out,o)
    return out
d=f'{AC}tenuto_tee/{TAG}/'
for fn in os.listdir(d): os.remove(d+fn)
def save(x,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(d+name)
save(piece(2),'arm_stub_behind_body.png'); save(piece(7,8,9,10),'tee.png'); save(piece(11,12),'sleeve_viewer_left.png'); save(piece(13),'forearm_viewer_left.png'); save(piece(14),'upper_arm_viewer_right.png')
save(piece(15,16),'sleeve_viewer_right.png'); save(piece(17),'flute.png'); save(piece(18),'forearm_viewer_right.png'); save(piece(2)*0,'empty.png')
m=json.load(open(P+'manifest.json'))
for s_ in [s_ for s_ in m['accessory_slots'] if s_.startswith('tee_') or s_=='shirt_sleeves']: del m['accessory_slots'][s_]
m['accessory_slots'].setdefault('behind_body',{'before':'1_pepper_body'}); m['accessory_slots']['shirt_over']={'after':'5_legs_feet','note':'sleeves and arm pieces that lie on the shirt, under the flute'}
open(P+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
c=json.load(open(AC+'catalog.json'))
[i for i in c['items'] if i['id']=='tenuto_tee'][0]['art'][TAG]=[{'slot':'behind_body','file':'arm_stub_behind_body.png'},{'slot':'shirt','file':'tee.png'},
  {'slot':'shirt_over','file':'sleeve_viewer_left.png'},{'slot':'shirt_over','file':'forearm_viewer_left.png'},{'slot':'shirt_over','file':'upper_arm_viewer_right.png'},{'slot':'shirt_over','file':'sleeve_viewer_right.png'},
  {'replaces':'6_flute','file':'flute.png'},{'replaces':'7_left_arm','file':'forearm_viewer_right.png'},{'replaces':'8_right_arm','file':'empty.png'}]
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
