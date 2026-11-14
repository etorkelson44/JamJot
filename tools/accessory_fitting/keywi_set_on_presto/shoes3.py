import json, os, sys, numpy as np, cv2
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
from PIL import Image
A=F.AR; AC=A+'accessories/'; J,BO,SN='jazzy_joggers','lilac_platform_boots','red_sneakers'
TAGS=['avatar_pose/jalapeno_standing','avatar_instrument/jalapeno_acoustic_guitar','avatar_instrument/jalapeno_electric_guitar','avatar_instrument/jalapeno_ukulele']
c=json.load(open(AC+'catalog.json')); by={i['id']:i for i in c['items']}
sb=Image.open(A+TAGS[0]+'/5_legs_feet.png').getbbox(); sd=f'{AC}{SN}/jalapeno_standing/'
def sv(a,p): Image.fromarray((np.clip(a,0,1)*255).round().astype('uint8')).save(p)
for tag in TAGS:
    t=tag.split('/')[1]; m,leg,a=F.legs_of(tag); bb=Image.open(A+tag+f'/{leg}.png').getbbox()
    p=A+tag+'/manifest.json'; m['accessory_slots']['shoes_over_pants']={'after':leg,'note':'the crossed foot\'s shoe, in front of both pant legs'}; open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
    # lace-ups: flat shoe under the pants, upright (crossed foot) shoe in front of both pant legs
    d=f'{AC}{SN}/{t}/'; k=(bb[2]-bb[0])/(sb[2]-sb[0]); M=np.float32([[k,0,bb[0]-sb[0]*k],[0,k,bb[1]-sb[1]*k]])
    for src,name in (('1_sneaker_flat.png','flat_with_joggers.png'),('2_sneaker_upright.png','crossed_with_joggers.png')):
        x=F.lay(sd+src)
        if t!='jalapeno_standing':
            pm=np.concatenate([x[...,:3]*x[...,3:],x[...,3:]],-1); o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); x=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
        sv(x,d+name)
    base=[{kk:v for kk,v in q.items() if kk not in('unless_worn','when_worn')} for q in by[SN]['art'][t] if 'when_worn' not in q]
    by[SN]['art'][t]=[dict(q,unless_worn=[J]) if q.get('slot')=='shoes' else q for q in base]+[{'slot':'shoes','file':'flat_with_joggers.png','when_worn':[J]},{'slot':'shoes_over_pants','file':'crossed_with_joggers.png','when_worn':[J]}]
    # boots: legs run down into the boots, but never show through the gap between heel and sole
    d=f'{AC}{BO}/{t}/'; legs=a.copy(); hide=np.zeros(legs.shape[:2],np.uint8)
    for q in by[BO]['art'][t]:
        if q.get('slot')=='shoes' and 'when_worn' not in q:
            al=(F.lay(d+q['file'])[...,3]>0.5).astype(np.uint8); h=np.zeros_like(al); cv2.fillConvexPoly(h,cv2.convexHull(cv2.findNonZero(al)),1); hide|=h
    legs[...,3]*=1-cv2.GaussianBlur(hide.astype(np.float32),(0,0),0.6); sv(legs,d+'legs_into_boots.png')
    by[BO]['art'][t]=[q for q in by[BO]['art'][t] if not q.get('replaces')]+[{'replaces':leg,'file':'legs_into_boots.png'}]
open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
