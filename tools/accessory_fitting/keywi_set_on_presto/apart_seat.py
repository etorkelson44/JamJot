import json, os, sys, numpy as np
os.chdir('/home/claude/pp'); sys.path.insert(0,'/home/claude/pp')
import fit2 as F, apart
from PIL import Image
A=F.AR; AC=A+'accessories/'; T,B=40,110
def save(x,item,t,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x[:1000]; Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(f'{AC}{item}/{t}/{name}')
for n in ['violin','viola','double_bass','flute','piano']:
    tag='avatar_instrument/jalapeno_'+n; t='jalapeno_'+n; m,leg,a=F.legs_of(tag); bb=Image.open(A+tag+f'/{leg}.png').getbbox(); sc=(bb[3]-bb[1])/191; kw=.22*sc; waist=bb[1]-8*sc
    Aa,Bb,crotch,(Li,Ri),cuff=F.joggers_two_legs(a,kw,waist); cx=lambda info: float(np.interp(cuff,np.array(info['cl'])[:,1],np.array(info['cl'])[:,0])); mid=(cx(Li)+cx(Ri))/2
    body=F.lay(A+tag+f'/{m["layers"][0]}.png')[...,3]; seat=F.seat_fill(body,mid,waist,kw,(cuff-waist)/F.ph)
    save(F.trimmed_legs(a,cuff),'jazzy_joggers',t,'legs.png'); save(F.over(F.over(seat,Aa),Bb),'jazzy_joggers',t,'joggers.png')
    if n=='piano':
        sL=F.sandal(Li['fx'][1],Li['fx'][0],Li['bot']); sR=F.sandal(Ri['fx'][0],Ri['fx'][1],Ri['bot']); save(F.over(sL[0],sR[0]),'serenade_sandals',t,'soles.png'); save(F.over(sL[1],sR[1]),'serenade_sandals',t,'straps.png')
    print(n,'waist',round(waist),'cuff',cuff)
