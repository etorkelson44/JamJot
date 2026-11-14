# Carries Erika's hat, glasses and tee (presto_top_half.pdf, fitted to the regular pose) to Señor Jalapresto's nine
# instrument poses: hat, glasses and shirt body follow his body (same pepper, moved and scaled); sleeves are redrawn in
# her style on each pose's arms.
import json, os, numpy as np, cv2, sys
from PIL import Image
sys.path.insert(0,'/home/claude/pp'); sys.path.insert(0,'/home/claude/th'); import fit2 as F, std
A=F.AR; AC=A+'accessories/'; T,B=40,110
STD_BB=Image.open(A+'avatar_pose/jalapeno_standing/1_body.png').getbbox()
# her sleeves on the regular pose -> size and placement relative to the arm
def sleeve_spec(piece,shoulder,toward):
    al=(piece[...,3]>0.5).astype(np.uint8); pts=cv2.findNonZero(al).reshape(-1,2).astype(float); p=np.array(shoulder,float); d=np.array(toward,float)-p; d/=np.hypot(*d); n=np.array([-d[1],d[0]])
    u=(pts-p)@d; v=(pts-p)@n; return dict(inset=-np.percentile(u,1),length=np.percentile(u,99),width=np.percentile(v,99)-np.percentile(v,1),off=(np.percentile(v,99)+np.percentile(v,1))/2)
SL=sleeve_spec(std.P['sl'],(420,598),(220,668)); SR=sleeve_spec(std.P['sr'],(585,603),(700,497))
SPEC={k:(SL[k]+SR[k])/2 for k in ('inset','length','width')}
_t=std.P['sl']; _m=_t[...,3]>0.5; BLUE=np.median(_t[_m&(_t[...,:3].max(-1)>0.5)][:,:3],0); INK=np.array([0,0,0.])
def sleeve(shoulder,toward,s=1.0,ink=5.2,inset=None):
    p=np.array(shoulder,float); d=np.array(toward,float)-p; d/=np.hypot(*d); n=np.array([-d[1],d[0]]); a=p-d*(SPEC['inset'] if inset is None else inset)*s; b=p+d*SPEC['length']*s; w=(SPEC['width']-ink)*s
    poly=np.array([a+n*w/2,b+n*w/2,b-n*w/2,a-n*w/2]); S=4; im=np.zeros((1000*S,1000*S),np.uint8); q=[np.round(poly*S).astype(np.int32)]; cv2.fillPoly(im,q,255)
    ln=np.zeros_like(im); cv2.polylines(ln,q,True,255,int(round(ink*s*S)),cv2.LINE_AA)
    f=cv2.resize(im,(1000,1000),interpolation=cv2.INTER_AREA).astype(np.float32)/255; k=cv2.resize(ln,(1000,1000),interpolation=cv2.INTER_AREA).astype(np.float32)/255
    o=np.zeros((1000,1000,4),np.float32); o[...,:3]=BLUE; o[...,3]=f; l=np.zeros_like(o); l[...,:3]=INK; l[...,3]=k; return F.over(o,l)
def moved(piece,bb):
    s=((bb[2]-bb[0])/(STD_BB[2]-STD_BB[0])+(bb[3]-bb[1])/(STD_BB[3]-STD_BB[1]))/2; M=np.float32([[s,0,bb[0]-STD_BB[0]*s],[0,s,bb[1]-STD_BB[1]*s]])
    pm=np.concatenate([piece[...,:3]*piece[...,3:],piece[...,3:]],-1); o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA if s<1 else cv2.INTER_LINEAR); al=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1), s
# arm layer -> (shoulder, a point further along the arm), read off each pose
ARMS={'violin':{'5_left_arm_hand':((560,605),(626,650)),'9_right_arm_bow_hand':((367,603),(314,623))},
      'viola':{'4_left_arm_hand':((547,597),(641,644)),'5_right_upper_arm':((368,603),(314,623))},
      'piano':{'7_arm_viewer_left':((401,540),(371,560)),'8_arm_viewer_right':((541,536),(575,554))},
      'flute':{'7_left_arm':((596,581),(440,476)),'8_right_arm':((408,601),(218,530))},
      'acoustic_guitar':{'6_fret_arm':((533,613),(698,608)),'9_strum_arm_hand':((371,638),(383,696))},
      'electric_guitar':{'6_fret_arm':((533,613),(698,608)),'9_strum_arm_hand':((371,638),(383,696))},
      'ukulele':{'6_fret_arm':((533,613),(710,572)),'9_strum_arm_hand':((372,638),(392,689))},
      'cello':{'6_left_upper_arm':((567,557),(703,548)),'10_right_arm':((350,562),(266,563))},
      'double_bass':{'6_left_upper_arm':((668,551),(743,472)),'10_right_arm':((351,542),(278,575))}}
def save(x,item,tag,name):
    c=np.zeros((1000+T+B,1000,4),np.float32); c[T:T+1000]=x; d=f'{AC}{item}/{tag}/'; os.makedirs(d,exist_ok=True); Image.fromarray((np.clip(c,0,1)*255).round().astype('uint8')).save(d+name)
if __name__=='__main__':
    print('sleeve spec',SPEC,SL,SR)
    art={'ballad_bucket_hat':{},'fermata_frames':{},'tenuto_tee':{}}
    for pose,arms in ARMS.items():
        tag='jalapeno_'+pose; p=A+'avatar_instrument/'+tag+'/manifest.json'; m=json.load(open(p)); body=[l for l in m['layers'] if 'body' in l][0]; leg=[l for l in m['layers'] if 'legs' in l][0]
        bb=Image.open(A+f'avatar_instrument/{tag}/{body}.png').getbbox()
        hat,s=moved(std.P['hat'],bb); gl,_=moved(std.P['glasses'],bb); tee,_=moved(std.P['tee'],bb)
        save(hat,'ballad_bucket_hat',tag,'hat.png'); save(gl,'fermata_frames',tag,'frames.png'); save(tee,'tenuto_tee',tag,'tee.png')
        m['accessory_slots']['shirt']={'after':leg,'note':'shirt body: over the legs and the pants waistband, under instruments and arms'}
        pieces=[{'slot':'shirt','file':'tee.png'}]
        for layer,(sh,to) in arms.items():
            slot='tee_sleeve_'+layer; m['accessory_slots'][slot]={'after':layer,'note':'short sleeve round the top of this arm'}
            f=f'sleeve_{layer}.png'; sv=sleeve(sh,to,s); save(sv,'tenuto_tee',tag,f); pieces.append({'slot':slot,'file':f})
            # In Erika's layers the shirt body sits over the sleeves. Here the sleeve has to sit on the arm, which is in
            # front of the shirt, so a copy of the shirt body is drawn back over the sleeve where the two overlap
            # (not over anything that is between the shirt and this arm, such as the instrument).
            li=m['layers'].index(layer); between=[l for l in m['layers'][m['layers'].index(leg)+1:li]]
            occ=np.zeros((1000,1000),np.float32)
            for l in between: occ=np.maximum(occ,F.lay(A+f'avatar_instrument/{tag}/{l}.png')[...,3])
            cover=sleeve(sh,to,s,inset=14)[...,3]; cover=cv2.dilate((cover>0.02).astype(np.uint8),np.ones((7,7),np.uint8)).astype(np.float32)   # the sleeve plus the bit of arm between the shoulder and the sleeve
            patch=tee.copy(); patch[...,3]*=cover*(1-occ); f2=f'tee_over_{layer}.png'; save(patch,'tenuto_tee',tag,f2); pieces.append({'slot':slot,'file':f2})
        open(p,'w').write(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
        art['tenuto_tee'][tag]=pieces; art['fermata_frames'][tag]=[{'slot':'face','file':'frames.png'}]
        art['ballad_bucket_hat'][tag]=[{'slot':'hat_behind_instrument' if 'hat_behind_instrument' in m['accessory_slots'] else 'hat','file':'hat.png'}]
    c=json.load(open(AC+'catalog.json'))
    for it in c['items']:
        if it['id'] in art: it['art'].update(art[it['id']])
    open(AC+'catalog.json','w').write(json.dumps(c,indent=2,ensure_ascii=False)+'\n')
    pp='/home/claude/jamjot/app/pubspec.yaml'; s_=open(pp).read(); anchor='    - assets/art/accessories/black_top_hat/\n'; add=''
    for item in art:
        for t in art[item]:
            line=f'    - assets/art/accessories/{item}/{t}/\n'
            if line not in s_ and line not in add: add+=line
    open(pp,'w').write(s_.replace(anchor,add+anchor,1))
