# Wires Erika's hat, glasses and tee (presto_top_half.pdf) onto Señor Jalapresto's regular pose.
import json, os, numpy as np, sys
from PIL import Image
sys.path.insert(0,'/home/claude/th'); import std
AC='/home/claude/jamjot/app/assets/art/accessories/'; T,B=40,110; TAG='jalapeno_standing'
def save(x,item,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; d=f'{AC}{item}/{TAG}/'; os.makedirs(d,exist_ok=True); Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(d+name)
P=std.P
save(P['hat'],'ballad_bucket_hat','hat.png'); save(P['glasses'],'fermata_frames','frames.png'); save(P['sr'],'tenuto_tee','sleeve_viewer_right.png'); save(P['sl'],'tenuto_tee','sleeve_viewer_left.png'); save(P['tee'],'tenuto_tee','tee.png')
art={'ballad_bucket_hat':[{'slot':'hat','file':'hat.png'}],'fermata_frames':[{'slot':'face','file':'frames.png'}],
     'tenuto_tee':[{'slot':'clothing_lower','file':'sleeve_viewer_right.png'},{'slot':'clothing_lower','file':'sleeve_viewer_left.png'},{'slot':'clothing_lower','file':'tee.png'}]}
c=json.load(open(AC+'catalog.json'))
for it in c['items']:
    if it['id'] in art:
        it['art'][TAG]=art[it['id']]
        if it['id']=='ballad_bucket_hat': it.setdefault('frames',{})[TAG]=[0,2,985]
note=" Ballad Bucket Hat, Fermata Frames and Tenuto Tee on Señor Jalapresto's regular pose are Erika's own layers (presto_top_half.pdf, 2026-11-13): sleeves over the arms, tee over the sleeves and over the joggers' waistband, glasses over the mustache."
if 'presto_top_half.pdf' not in c['note']: c['note']=c['note'].rstrip()+note
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
p='/home/claude/jamjot/app/pubspec.yaml'; s=open(p).read(); anchor='    - assets/art/accessories/black_top_hat/\n'; add=''
for item in art:
    line=f'    - assets/art/accessories/{item}/{TAG}/\n'
    if line not in s: add+=line
open(p,'w').write(s.replace(anchor,add+anchor,1))
