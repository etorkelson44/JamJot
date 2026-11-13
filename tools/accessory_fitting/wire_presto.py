# Wires the Jazzy Joggers and Serenade Sandals into Presto's ten poses and adds Keywi's "pants over the boots" pieces.
import json, os, numpy as np, cv2, sys
from PIL import Image
sys.path.insert(0,'/home/claude/kw')
import fit2 as F, v3, apart, cello
A='/home/claude/jamjot/app/assets/art/'; AC=A+'accessories/'; T,B=40,110; H=1000+T+B
J,S='jazzy_joggers','serenade_sandals'; OTHER_SHOES=['lilac_platform_boots','red_sneakers']
def save(x,item,tag,name):
    c=np.zeros((H,1000,4),np.float32); c[T:T+1000]=x[:1000]; d=f'{AC}{item}/{tag}/'; os.makedirs(d,exist_ok=True)
    Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(d+name)
def slots(tag,add):
    p=A+tag+'/manifest.json'; m=json.load(open(p)); m['accessory_slots'].update(add); open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
art={J:{},S:{}}
# --- crossed legs: standing, acoustic guitar, electric guitar, ukulele ---
for tag in ['avatar_pose/jalapeno_standing','avatar_instrument/jalapeno_acoustic_guitar','avatar_instrument/jalapeno_electric_guitar','avatar_instrument/jalapeno_ukulele']:
    m,leg,a=F.legs_of(tag); bb=Image.open(A+tag+f'/{leg}.png').getbbox(); P={k:v3.to_canvas(v,bb) for k,v in v3.PIE.items()}; t=tag.split('/')[1]
    body=F.lay(A+tag+f'/{m["layers"][0]}.png')[...,3]; k=(bb[2]-bb[0])/581; back=F.gusset(P['A'],P['B'],body,bb[1]+(275-4)*k)
    save(back,J,t,'back.png'); save(P['F2'],J,t,'foot.png'); save(P['B'],J,t,'front.png')
    save(F.over(P['S1'],P['S2']),S,t,'soles.png'); save(F.over(P['U1'],P['U2']),S,t,'straps.png')
    for n,k_ in (('sole_flat','S1'),('strap_flat','U1'),('sole_tiptoe','S2'),('strap_tiptoe','U2')): save(P[k_],S,t,n+'.png')
    slots(tag,{'shoes_under':{'before':leg,'note':'sandal soles: under the feet'},
        'pants_back':{'after':leg,'note':'the pant leg of the straight (back) leg'},'shoes_mid_under':{'after':leg,'note':'sole of the crossed foot, in front of the back pant leg'},
        'pants_foot':{'after':leg,'note':'the crossed foot again, in front of the back pant leg'},'shoes_mid':{'after':leg,'note':'straps of the crossed foot'},
        'pants':{'after':leg,'note':'the pant leg of the crossed (front) leg; under instruments'}})
    art[J][t]=[{'slot':'pants_back','file':'back.png'},{'slot':'pants_foot','file':'foot.png','unless_worn':OTHER_SHOES},{'slot':'pants','file':'front.png'}]
    art[S][t]=[{'slot':'shoes_under','file':'soles.png','unless_worn':[J]},{'slot':'shoes','file':'straps.png','unless_worn':[J]},
               {'slot':'shoes_under','file':'sole_flat.png','when_worn':[J]},{'slot':'shoes','file':'strap_flat.png','when_worn':[J]},
               {'slot':'shoes_mid_under','file':'sole_tiptoe.png','when_worn':[J]},{'slot':'shoes_mid','file':'strap_tiptoe.png','when_worn':[J]}]
# --- legs apart (violin, viola, double bass, flute, piano) and seated (cello) ---
for tag in ['avatar_instrument/jalapeno_'+n for n in ['violin','viola','double_bass','flute','piano','cello']]:
    P=cello.build() if tag.endswith('cello') else apart.build(tag); t=tag.split('/')[1]; leg=P['leg']
    save(P['legs_trim'],J,t,'legs.png'); save(F.over(P['A'],P['B']),J,t,'joggers.png'); save(P['soles'],S,t,'soles.png'); save(P['straps'],S,t,'straps.png')
    slots(tag,{'shoes_under':{'before':leg,'note':'sandal soles: under the feet'},'pants':{'after':leg,'note':'pants: over legs and shoes, under instruments'}})
    art[J][t]=[{'replaces':leg,'file':'legs.png'},{'slot':'pants','file':'joggers.png'}]
    art[S][t]=[{'slot':'shoes_under','file':'soles.png'},{'slot':'shoes','file':'straps.png'}]
# --- Keywi: pants over the Bravura Boots (option B, Erika 2026-11-13 15:14 CT) ---
import boots as BT
for f,leg in (('1_boot_viewer_left',BT.PA),('2_boot_viewer_right',BT.PB)):
    x=BT.over_boots(BT.bl if 'left' in f else BT.br,leg); Image.fromarray((np.clip(x,0,1)*255).round().astype('uint8')).save(f'{AC}lilac_platform_boots/kiwi_standing/{f}_under_joggers.png')
c=json.load(open(AC+'catalog.json'))
for it in c['items']:
    if it['id'] in art: it['art'].update(art[it['id']])
    if it['id']=='lilac_platform_boots':
        base=[{k:v for k,v in q.items() if k!='unless_worn'} for q in it['art']['kiwi_standing'] if 'when_worn' not in q]
        it['art']['kiwi_standing']=[dict(q,unless_worn=[J]) for q in base]+[{'slot':q['slot'],'file':q['file'].replace('.png','_under_joggers.png'),'when_worn':[J]} for q in base]
note=" Jazzy Joggers and Serenade Sandals are fitted to Keywi's normal legs and to all ten of Señor Jalapresto's poses (2026-11-13): on his crossed-leg poses the joggers come in a back leg, the crossed foot and a front leg so the sandal can sit between them; on legs-apart and seated poses the joggers replace the legs layer with one trimmed above the cuffs. With the joggers on Keywi the Bravura Boots use a version hidden above the pant cuffs (pants over boots)."
if 'all ten of Señor Jalapresto' not in c['note']: c['note']=c['note'].rstrip()+note
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
p='/home/claude/jamjot/app/pubspec.yaml'; s=open(p).read(); anchor='    - assets/art/accessories/black_top_hat/\n'; add=''
for item in art:
    for t in art[item]:
        line=f'    - assets/art/accessories/{item}/{t}/\n'
        if line not in s and line not in add: add+=line
open(p,'w').write(s.replace(anchor,add+anchor,1)); print('tags',{k:len(v) for k,v in art.items()})
