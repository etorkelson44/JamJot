import json, os, sys, numpy as np, cv2
os.chdir('/home/claude/pp'); sys.path.insert(0,'/home/claude/pp'); sys.path.insert(0,'/home/claude/th')
import fit2 as F, v3, shoes_cross as SC
from PIL import Image
A=F.AR; AC=A+'accessories/'; J,BO,SN='jazzy_joggers','lilac_platform_boots','red_sneakers'; T,B=40,110
Lps=[(145,-30),(145,290),(165,420),(182,530)]; Rps=[(396,-30),(396,270),(414,345),(424,400),(404,480)]
As=v3.ribbon(Lps,0,v3.XC+3,v3.XL,.78,v3.kl); Bs=v3.ribbon(Rps,v3.XC-3,v3.pw,v3.XR,.78,v3.kl)
def save(x,item,t,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x[:1000]; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(f'{AC}{item}/{t}/{name}')
c=json.load(open(AC+'catalog.json')); by={i['id']:i for i in c['items']}
for tag in SC.TAGS:
    t=tag.split('/')[1]; m,leg,a=F.legs_of(tag); bb=Image.open(A+tag+f'/{leg}.png').getbbox(); k=(bb[2]-bb[0])/581
    PA=v3.to_canvas(As,bb); PB=v3.to_canvas(Bs,bb); body=F.lay(A+tag+f'/{m["layers"][0]}.png')[...,3]
    back=F.over(F.seat_fill(body,bb[0]+(270.5-4)*k,bb[1]+(-30-4)*k,.78*k,v3.kl*k),PA); save(back,J,t,'back_short.png'); save(PB,J,t,'front_short.png')
    base=[{kk:v for kk,v in p.items() if kk not in('unless_worn','when_worn')} for p in by[J]['art'][t] if not p['file'].endswith('_short.png')]
    new=[]
    for p in base:
        if p['file'] in('back.png','front.png'): new+= [dict(p,unless_worn=[BO]),dict(p,file=p['file'].replace('.png','_short.png'),when_worn=[BO])]
        else: new.append(dict(p,unless_worn=[BO,SN]))
    by[J]['art'][t]=new
    # boots under the short joggers
    it=by[BO]; d=f'{AC}{BO}/{t}/'; shoes=[p for p in it['art'][t] if p.get('slot')=='shoes' and 'when_worn' not in p]
    byx=sorted(shoes,key=lambda p: Image.open(d+p['file']).getbbox()[0]); tip,flat=F.lay(d+byx[0]['file']),F.lay(d+byx[1]['file'])
    for arr,name in ((SC.graded(flat,PA),'flat_with_joggers.png'),(SC.graded(tip,PB),'crossed_with_joggers.png')): Image.fromarray((np.clip(arr,0,1)*255).round().astype('uint8')).save(d+name)
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
for i in (BO,SN):
    for t,ps in by[i]['art'].items():
        r=[p for p in ps if p.get('replaces')]
        if r: print(i,t,r)
