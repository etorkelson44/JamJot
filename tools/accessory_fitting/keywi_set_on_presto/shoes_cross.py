# Legato Lace-Ups and Bravura Boots with the Jazzy Joggers on Señor Jalapresto's crossed-leg poses: the flat foot's shoe
# stays under the back pant leg, the crossed foot's shoe moves in front of it (under the front pant leg), and boots are
# hidden above each pant leg's cuff with the sloped edge used on Keywi.
import json, numpy as np, cv2, sys
from PIL import Image
sys.path.insert(0,'/home/claude/pp'); import os; os.chdir('/home/claude/pp'); import fit2 as F, v3
A=F.AR; AC=A+'accessories/'; J='jazzy_joggers'
TAGS=['avatar_pose/jalapeno_standing','avatar_instrument/jalapeno_acoustic_guitar','avatar_instrument/jalapeno_electric_guitar','avatar_instrument/jalapeno_ukulele']
def end_plane(pts,bb,k):
    P,s,T=v3.curve(pts); E=np.array([bb[0]+(P[-1][0]-4)*k,bb[1]+(P[-1][1]-4)*k]); return E,T[-1]
def cuff_line(leg):
    """Per column: where a boot may start showing under this pant leg (same rule as Keywi's pants over boots): under the
    flat underside of the cuff it is that edge; everywhere else it is the pant leg's lowest point."""
    al=leg[...,3]>0.5; cols=np.nonzero(al.any(0))[0]; bot=np.array([np.nonzero(al[:,x])[0].max() for x in cols]).astype(float)
    flat=np.abs(np.gradient(bot))<1.0; runs=[]; st=None
    for i,f in enumerate(flat):
        if f and st is None: st=i
        if (not f or i==len(flat)-1) and st is not None: runs.append((st,i if not f else i+1)); st=None
    line=np.full(leg.shape[1],float(bot.max()))
    if runs:
        lo,hi=max(runs,key=lambda r:r[1]-r[0]); lo,hi=lo+4,hi-4
        if hi>lo: line[cols[lo]:cols[hi-1]+1]=bot[lo:hi]
    return line
def graded(shoe,leg):
    """Pants over boots: the boot shows only below this pant leg's cuff, with a sloped edge instead of a step."""
    yy=np.arange(shoe.shape[0])[:,None]; keep=(yy>=cuff_line(leg)[None,:]-2)&(shoe[...,3]>0.5)
    if keep.sum()<20: return shoe*0
    hull=np.zeros(keep.shape,np.uint8); cv2.fillConvexPoly(hull,cv2.convexHull(cv2.findNonZero(keep.astype(np.uint8))),1)
    o=shoe.copy(); o[...,3]*=np.clip(cv2.GaussianBlur(hull.astype(np.float32),(0,0),0.8)*1.6-0.3,0,1); return o
def split(a):
    """one-file shoe pair -> (flat foot's shoe, crossed foot's shoe)"""
    n,lab,st,cen=cv2.connectedComponentsWithStats((a[...,3]>0.3).astype(np.uint8)); big=sorted(range(1,n),key=lambda i:-st[i,4])[:2]
    if len(big)==2 and st[big[1],4]>0.15*st[big[0],4]:
        big=sorted(big,key=lambda i:cen[i][0]); tip,flat=big      # the crossed (tiptoe) foot is on the viewer's left
        m=lambda i: a*((lab==i)|((lab!=big[0])&(lab!=big[1])&(np.abs(np.arange(a.shape[1])[None,:]-cen[i][0])<np.abs(np.arange(a.shape[1])[None,:]-cen[big[0] if i==big[1] else big[1]][0]))))[...,None]
        return m(flat),m(tip)
    return None
def run(write=True):
    c=json.load(open(AC+'catalog.json')); out={}
    for tag in TAGS:
        t=tag.split('/')[1]; m,leg,a=F.legs_of(tag); bb=Image.open(A+tag+f'/{leg}.png').getbbox(); k=(bb[2]-bb[0])/581
        PA=v3.to_canvas(v3.PIE['A'],bb); PB=v3.to_canvas(v3.PIE['B'],bb)
        for it in c['items']:
            if it['id'] not in ('red_sneakers','lilac_platform_boots') or t not in it['art']: continue
            base=[{kk:v for kk,v in p.items() if kk!='unless_worn'} for p in it['art'][t] if 'when_worn' not in p and not p['file'].endswith('_split.png')]
            shoes=[p for p in base if p.get('slot')=='shoes']; rest=[p for p in base if p.get('slot')!='shoes']; d=f"{AC}{it['id']}/{t}/"
            L={p['file']:F.lay(d+p['file']) for p in shoes}
            if len(shoes)==1:
                sp=split(L[shoes[0]['file']])
                if sp is None: print('could not split',it['id'],t); continue
                flat,tip=sp
            else:
                byx=sorted(shoes,key=lambda p: Image.open(d+p['file']).getbbox()[0]); tip,flat=L[byx[0]['file']],L[byx[1]['file']]
            boots=it['id']=='lilac_platform_boots'
            fj=graded(flat,PA) if boots else flat; tj=graded(tip,PB) if boots else tip
            if write:
                for arr,name in ((fj,'flat_with_joggers.png'),(tj,'crossed_with_joggers.png')): Image.fromarray((np.clip(arr,0,1)*255).round().astype('uint8')).save(d+name)
            it['art'][t]=[dict(p,unless_worn=[J]) for p in shoes]+[{'slot':'shoes','file':'flat_with_joggers.png','when_worn':[J]},{'slot':'shoes_mid','file':'crossed_with_joggers.png','when_worn':[J]}]+rest
            out[(it['id'],t)]=(fj,tj)
    if write: open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
    return out
if __name__=='__main__': print(len(run()))
