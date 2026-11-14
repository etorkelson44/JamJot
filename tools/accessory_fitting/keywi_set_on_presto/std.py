# Señor Jalapresto, regular pose: Ballad Bucket Hat, Fermata Frames and Tenuto Tee from Erika's layered PDF presto_top_half.pdf
import numpy as np, cv2, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0,'/home/claude/pp'); import fit2 as F
AR=F.AR; TAG='avatar_pose/jalapeno_standing'
bb_pdf=Image.open('body.png').getbbox(); bb_app=Image.open(AR+TAG+'/1_body.png').getbbox()
kx=(bb_app[2]-bb_app[0])/(bb_pdf[2]-bb_pdf[0]); ky=(bb_app[3]-bb_app[1])/(bb_pdf[3]-bb_pdf[1]); k=(kx+ky)/2
M=np.float32([[k,0,bb_app[0]-bb_pdf[0]*k],[0,k,bb_app[1]-bb_pdf[1]*k]])
def piece(*names):
    out=None
    for n in names:
        a=np.asarray(Image.open(n+'.png').convert('RGBA')).astype(np.float32)/255; pm=np.concatenate([a[...,:3]*a[...,3:],a[...,3:]],-1)
        o=cv2.warpAffine(pm,M,(1000,1000),flags=cv2.INTER_AREA); al=np.maximum(o[...,3:],1e-6); o=np.concatenate([np.clip(o[...,:3]/al,0,1),np.clip(o[...,3:],0,1)],-1)
        out=o if out is None else F.over(out,o)
    return out
P=dict(hat=piece('hat'),glasses=piece('glasses'),tee=piece('tee_border','tee_fill','tee_line','logo'),sl=piece('sleeve_l_fill','sleeve_l_line'),sr=piece('sleeve_r_fill','sleeve_r_line'))
L=lambda n: F.lay(AR+TAG+f'/{n}.png')
ac=AR+'accessories/'; g=lambda i,f: F.lay(ac+f'{i}/jalapeno_standing/{f}')[40:1040]
JS=dict(sole_flat=g('serenade_sandals','sole_flat.png'),strap_flat=g('serenade_sandals','strap_flat.png'),sole_tip=g('serenade_sandals','sole_tiptoe.png'),strap_tip=g('serenade_sandals','strap_tiptoe.png'),
        soles=g('serenade_sandals','soles.png'),straps=g('serenade_sandals','straps.png'),back=g('jazzy_joggers','back.png'),foot=g('jazzy_joggers','foot.png'),front=g('jazzy_joggers','front.png'))
def render(what):
    w=set(what); ls=[L('1_body'),L('4_eyes_brows'),L('3_teeth'),L('2_mustache')]
    if 'glasses' in w: ls.append(P['glasses'])
    j,s='joggers' in w,'sandals' in w
    if s: ls.append(JS['sole_flat'] if j else JS['soles'])
    ls.append(L('5_legs_feet'))
    if s: ls.append(JS['strap_flat'] if j else JS['straps'])
    if j: ls+= [JS['back']]+([JS['sole_tip']] if s else [])+[JS['foot']]+([JS['strap_tip']] if s else [])+[JS['front']]
    ls+= [L('6_arm_viewer_right'),L('7_arm_viewer_left')]
    if 'tee' in w: ls+= [P['sr'],P['sl'],P['tee']]
    if 'hat' in w: ls.append(P['hat'])
    return F.img(F.flat(ls))
if __name__=='__main__':
    print('scale',kx,ky)
    cols=[('Plain',[]),('Ballad Bucket Hat',['hat']),('Fermata Frames',['glasses']),('Tenuto Tee',['tee']),('Hat + Frames + Tee',['hat','glasses','tee']),('Whole set',['hat','glasses','tee','joggers','sandals'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',24); cw=520
    W=Image.new('RGB',(cw*3,(cw+44)*2),'white'); d=ImageDraw.Draw(W)
    for i,(n,wh) in enumerate(cols):
        x,y=(i%3)*cw,(i//3)*(cw+44); W.paste(render(wh).resize((cw,cw),Image.LANCZOS),(x,y+44)); d.text((x+12,y+10),n,fill=(60,40,110),font=f)
    W.save('Presto_regular_pose_your_layers.png')
    a=Image.open('pg-1.png').convert('RGB').crop((150,0,850,1042)).resize((640,953)); b=render(['hat','glasses','tee']).crop((180,0,820,1000)).resize((640,1000),Image.LANCZOS); c=render(['hat','glasses','tee','joggers','sandals']).crop((180,0,820,1000)).resize((640,1000),Image.LANCZOS)
    Z=Image.new('RGB',(1960,1050),'white'); dz=ImageDraw.Draw(Z)
    for i,(n,im) in enumerate((('Your PDF',a),('In the app build',b),('With the joggers and sandals',c))): Z.paste(im,(i*655,45)); dz.text((i*655+10,8),n,fill=(60,40,110),font=f)
    Z.save('Presto_regular_pose_yours_vs_app.png')
