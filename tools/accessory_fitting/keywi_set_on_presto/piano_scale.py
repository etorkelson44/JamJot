# Makes Señor Jalapresto's piano pose the same size as his other poses (Erika, 2026-11-13 17:15 CT).
import json, glob, os, numpy as np, cv2
from PIL import Image
A='/home/claude/jamjot/app/assets/art/'; P=A+'avatar_instrument/jalapeno_piano/'; AC=A+'accessories/'
m=json.load(open(P+'manifest.json'))
if m.get('scaled_to_full_size'): raise SystemExit('already scaled')
bb=Image.open(P+'1_pepper_body.png').getbbox(); s=780/(bb[3]-bb[1]); tx=478-(bb[0]+bb[2])/2*s; ty=48-bb[1]*s; print('scale',s,tx,ty)
cat=json.load(open(AC+'catalog.json')); OT={}
for it in cat['items']:
    for p in it['art'].get('jalapeno_piano',[]): OT[f"{AC}{it['id']}/jalapeno_piano/{p['file']}"]=p.get('overflow_top',it.get('overflow_top',0))
    f=it.get('frames',{}).get('jalapeno_piano')
    if f: it['frames']['jalapeno_piano']=[round(f[0]*s+tx),round(f[1]*s+ty),round(f[2]*s)]
def warp(path,ot):
    im=Image.open(path).convert('RGBA'); a=np.asarray(im).astype(np.float32)/255; h,w=a.shape[:2]; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
    M=np.float32([[s,0,tx],[0,s,ty+ot-ot*s]]); o=cv2.warpAffine(pm,M,(w,h),flags=cv2.INTER_CUBIC); al=np.maximum(o[...,3:],1e-6); o=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
    r=o[...,3].sum()/max(a[...,3].sum(),1)/s/s
    if r<0.985: print('CLIPPED',path.replace(A,''),round(r,3))
    Image.fromarray((o*255).round().astype('uint8')).save(path)
for l in m['layers']: warp(P+l+'.png',0)
for f in glob.glob(AC+'*/jalapeno_piano/*.png'): warp(f,OT.get(f,0 if Image.open(f).size[1]==1000 else 40))
for k in ('display_box','dressed_display_box'):
    if k in m: m[k]=[round(m[k][0]*s+tx),round(m[k][1]*s+ty),round(m[k][2]*s)]
m['scaled_to_full_size']=f'layers and fitted accessories scaled x{s:.3f} on 2026-11-13 so this pose matches the others'
open(P+'manifest.json','w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n'); open(AC+'catalog.json','w').write(json.dumps(cat,indent=2,ensure_ascii=False)+'\n')
json.dump(dict(s=s,tx=tx,ty=ty),open('/home/claude/th/piano_M.json','w'))
# violin: the left hand goes behind the violin's neck (arm layer drawn before the violin)
V=A+'avatar_instrument/jalapeno_violin/manifest.json'; mv=json.load(open(V)); L=mv['layers']
if L.index('5_left_arm_hand')>L.index('4_violin'): L.remove('5_left_arm_hand'); L.insert(L.index('4_violin'),'5_left_arm_hand'); open(V,'w').write(json.dumps(mv,indent=2,ensure_ascii=False)+'\n'); print('violin layers',L)
