# Renders outfits exactly as the app would (catalog + manifest rules), ignoring the released switch.
import json, numpy as np
from PIL import Image, ImageDraw, ImageFont
A='/home/claude/jamjot/app/assets/art/'; AC=A+'accessories/'
RANK=['behind_body','shoes_under','shoes','pants_back','shoes_mid_under','pants_foot','shoes_mid','clothing_torso','clothing_lower','pants','shoes_over_pants','shirt_sleeves','shirt','shirt_over','tee_arm_over','tee_sleeve_over','jacket','shoes_front','sleeves_arm_viewer_right','sleeves_arm_viewer_left','face','hat']
CAT=json.load(open(AC+'catalog.json'))['items']; BY={i['id']:i for i in CAT}
def over(b,t):
    a=t[...,3:]; ba=b[...,3:]; oa=a+ba*(1-a); rgb=(t[...,:3]*a+b[...,:3]*ba*(1-a))/np.maximum(oa,1e-6); return np.concatenate([rgb,oa],-1)
def render(avatar,pose,ids,TOP=220,BOT=120):
    import os
    tag=f'{avatar}_{pose}'; PD=A+('avatar_pose/' if os.path.exists(A+f'avatar_pose/{tag}') else 'avatar_instrument/')+tag+'/'; m=json.load(open(PD+'manifest.json')); ids=[i for i in ids if not (any(BY[j].get('kind')=='dress' for j in ids) and BY[i].get('kind') in ('top','bottom'))]; worn={i for i in ids if tag in BY[i]['art']}
    acc=[]
    for i in ids:
        if i not in worn: continue
        it=BY[i]
        for p in it['art'][tag]:
            if not all(w in worn for w in p.get('when_worn',[])) or any(w in worn for w in p.get('unless_worn',[])): continue
            acc.append(dict(slot=p.get('slot',''),file=f'{AC}{i}/{tag}/{p["file"]}',replaces=p.get('replaces'),ot=p.get('overflow_top',it.get('overflow_top',0)),ob=p.get('overflow_bottom',it.get('overflow_bottom',0))))
    acc.sort(key=lambda a: RANK.index(a['slot']) if a['slot'] in RANK else len(RANK))
    rep={a['replaces']:a for a in acc if a['replaces'] in m['layers']}; order=[]
    def at(layer,after):
        k='after' if after else 'before'
        return [a for a in acc if not a['replaces'] and m['accessory_slots'].get(a['slot'],{}).get(k)==layer]
    for l in m['layers']:
        order+=at(l,False); order.append(rep.get(l) or dict(file=PD+f'{l}.png',ot=0,ob=0)); order+=at(l,True)
    c=np.zeros((1000+TOP+BOT,1000,4),np.float32); c[...,:3]=1; c[...,3]=1
    for a in order:
        im=Image.open(a['file']).convert('RGBA'); h=int(1000+a['ot']+a['ob'])
        if im.size!=(1000,h): im=im.resize((1000,h),Image.LANCZOS)
        x=np.asarray(im).astype(np.float32)/255; y0=int(TOP-a['ot']); lay=np.zeros_like(c); lay[y0:y0+h]=x; c=over(c,lay)
    return Image.fromarray((c[...,:3]*255).astype('uint8')), sorted(set(ids)-worn)
def sheet(title,rows,out,avatar='kiwi',pose='standing',cw=330):
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',17); fb=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',26); fs=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    ch=int(cw*1.34); n=max(len(r[1]) for r in rows); W=Image.new('RGB',(n*cw+20,60+len(rows)*(ch+86)),'white'); d=ImageDraw.Draw(W); d.text((14,14),title,fill=(60,40,110),font=fb)
    for ri,(rt,cells) in enumerate(rows):
        y=60+ri*(ch+86); d.text((14,y+4),rt,fill=(170,60,90),font=f)
        for ci,ids in enumerate(cells):
            im,missing=render(avatar,pose,ids); W.paste(im.resize((cw,ch),Image.LANCZOS),(10+ci*cw,y+70))
            names=[BY[i]['name'] for i in ids] or ['Plain']
            lines=[' + '.join(names[k:k+2]) for k in range(0,len(names),2)]
            for li,t in enumerate(lines): d.text((16+ci*cw,y+26+li*17),t,fill=(40,40,40),font=fs)
    W.save(out); print(out,W.size)
if __name__=='__main__':
    J,S,Bo,L='jazzy_joggers','serenade_sandals','lilac_platform_boots','red_sneakers'
    Hb,Ht,Hc,Hs='ballad_bucket_hat','black_top_hat','purple_glitter_crown','sugar_shrub_shako'; G,Mo,Ce='fermata_frames','gold_monocle','cat_eye_sunglasses'; Te,Tx,Fr='tenuto_tee','black_tuxedo','pink_ruffle_dress'
    sheet('Keywi: pants and shoes',[('No pants',[[S],[Bo],[L],[]]),('Jazzy Joggers',[[J,S],[J,Bo],[J,L],[J]]),('Tenuto Tee + Jazzy Joggers',[[Te,J,S],[Te,J,Bo],[Te,J,L],[Te,J]])],'Keywi_sheet_1_pants_and_shoes.png')
    sheet('Keywi: hats and glasses',[('Ballad Bucket Hat',[[Hb],[Hb,G],[Hb,Mo],[Hb,Ce]]),('Fermata Frames with the other hats',[[G],[Ht,G],[Hc,G],[Hs,G]])],'Keywi_sheet_2_hats_and_glasses.png')
    sheet('Keywi: tops and bottoms across sets',[('Tops with the Jazzy Joggers',[[Te,J],[Tx,J],[Tx,J,L],[Tx,J,Bo]]),('Tenuto Tee with other pieces',[[Te],[Te,Bo],[Te,L],[Te,Ht,Mo]]),('Falsetto Frock: a whole outfit, never with a shirt or pants',[[Fr],[Fr,S],[Fr,L],[Hb,G,Fr,Bo]]),('Whole sets and mixes',[[Hb,G,Te,J,S],[Ht,Mo,Tx,L],[Hc,Ce,Fr,Bo],[Hs,G,Te,J,L]])],'Keywi_sheet_3_tops_and_bottoms.png')
