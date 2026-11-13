import json, os, subprocess, numpy as np
from PIL import Image
import combos2 as C
A='/home/claude/jamjot/app/assets/art/'; AC=A+'accessories/'; TAG='kiwi_standing'
def save(arr,item,name):
    d=f'{AC}{item}/{TAG}/'; os.makedirs(d,exist_ok=True); Image.fromarray((np.clip(arr,0,1)*255).round().astype('uint8')).save(d+name)
so_app,st_app=C.sandals_on_app()
save(C.PIE['hat'],'ballad_bucket_hat','hat.png'); save(C.PIE['glasses'],'fermata_frames','frames.png')
save(C.PIE['armL2'],'tenuto_tee','arm_viewer_left.png'); save(C.PIE['armR2'],'tenuto_tee','arm_viewer_right.png'); save(C.PIE['tee'],'tenuto_tee','tee.png')
import sys; sys.path.insert(0,'/home/claude/pp'); import fit2 as F
# Joggers fitted to Keywi's normal legs (Erika, 2026-11-13 14:59 CT): no longer legs, no second shoe positions.
_m,_leg,_a=F.legs_of('avatar_pose/kiwi_standing'); _A,_B,_cr,_inf,_cuff=F.joggers_two_legs(_a,.22,702)
def pad(x):
    c=np.zeros((C.H,1000,4),np.float32); c[C.T:C.T+1000]=x[:1000]; return c
save(pad(F.trimmed_legs(_a,_cuff)),'jazzy_joggers','legs.png'); save(pad(F.over(_A,_B)),'jazzy_joggers','joggers.png')
save(so_app,'serenade_sandals','soles.png'); save(st_app,'serenade_sandals','straps.png')
m=json.load(open(A+f'avatar_pose/{TAG}/manifest.json')); db=m['dressed_display_box']; print('dressed box',db)
m['accessory_slots']['shoes_under']={'before':'4_legs_feet','note':'sandal soles: under the feet'}
m['accessory_slots']['pants']={'after':'6_arm_viewer_right','note':'pants: over shirts and jackets, under hats'}
open(A+f'avatar_pose/{TAG}/manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
def frame(top,bottom):
    t=min(db[1],top); b=max(db[1]+db[2],bottom); s=max(b-t,db[2]); return [round(db[0]+db[2]/2-s/2),t,s]
KIND={'tenuto_tee':'top','jazzy_joggers':'bottom'}
items=[
 ('ballad_bucket_hat','Ballad Bucket Hat',[{'slot':'hat','file':'hat.png'}],frame(-22,0)),
 ('fermata_frames','Fermata Frames',[{'slot':'face','file':'frames.png'}],None),
 ('tenuto_tee','Tenuto Tee',[{'replaces':'5_arm_viewer_left','file':'arm_viewer_left.png'},{'replaces':'6_arm_viewer_right','file':'arm_viewer_right.png'},{'slot':'clothing_lower','file':'tee.png'}],None),
 ('jazzy_joggers','Jazzy Joggers',[{'replaces':'4_legs_feet','file':'legs.png'},{'slot':'pants','file':'joggers.png'}],None),
 ('serenade_sandals','Serenade Sandals',[{'slot':'shoes_under','file':'soles.png'},{'slot':'shoes','file':'straps.png'}],None)]
# shelf images from Erika's accessories PDF: page 1 hat, 2 tee, 3 glasses, 4 sandals, 5 pants
pages={'ballad_bucket_hat':1,'tenuto_tee':2,'fermata_frames':3,'serenade_sandals':4,'jazzy_joggers':5}
import re
subprocess.run(['qpdf','--qdf','--object-streams=disable','/home/claude/kw/acc.pdf','/home/claude/kw/acc.q.pdf'])
d=open('/home/claude/kw/acc.q.pdf','rb').read(); d=re.sub(rb'(0 0 \d+ \d+ re\n)f',rb'\1n',d); open('/home/claude/kw/acc_t.pdf','wb').write(d)
subprocess.run(['fix-qdf','/home/claude/kw/acc_t.pdf'],stdout=open('/home/claude/kw/acc_tf.pdf','wb'))
subprocess.run(['pdftocairo','-png','-transp','-r','72','/home/claude/kw/acc_tf.pdf','/home/claude/kw/disp'])
c=json.load(open(AC+'catalog.json')); ids=[i[0] for i in items]; c['items']=[i for i in c['items'] if i['id'] not in ids]
for iid,name,art,fr in items:
    im=Image.open(f'/home/claude/kw/disp-{pages[iid]}.png').convert('RGBA'); a=np.asarray(im)[...,3]; ys,xs=np.nonzero(a>10); print(iid,'display alpha share',round((a>10).mean(),3))
    im=im.crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)); s=max(im.size); sq=Image.new('RGBA',(s,s),(0,0,0,0)); sq.alpha_composite(im,((s-im.size[0])//2,(s-im.size[1])//2)); sq.resize((512,512),Image.LANCZOS).save(f'{AC}{iid}/display.png')
    e={'id':iid,'name':name,**({'kind':KIND[iid]} if iid in KIND else {}),'released':False,'display':'display.png','overflow_top':C.T,'overflow_bottom':110,'art':{TAG:art}}
    if fr: e['frames']={TAG:fr}
    c['items'].append(e)
if 'Keywi\'s set (Ballad' not in c['note']: c['note']=c['note'].rstrip()+' Keywi\'s set (Ballad Bucket Hat, Fermata Frames, Tenuto Tee, Jazzy Joggers, Serenade Sandals; named by Erika 2026-11-13) is fitted to Keywi\'s standing pose only; when_worn / unless_worn on a piece pick the version that goes with another worn item.'
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
p='/home/claude/jamjot/app/pubspec.yaml'; s=open(p).read(); anchor='    - assets/art/accessories/black_top_hat/\n'; add=''
for iid in ids:
    for line in (f'    - assets/art/accessories/{iid}/\n',f'    - assets/art/accessories/{iid}/{TAG}/\n'):
        if line not in s: add+=line
open(p,'w').write(s.replace(anchor,add+anchor,1))
