from fit import *
import json
from PIL import ImageDraw, ImageFont
kw=.78
Lp=[(145,-30),(145,290),(170,450),(193,650),(213,835)]
Rp=[(396,-30),(396,270),(414,345),(424,400),(408,465),(338,542),(228,608),(120,642)]
kl=curve(Lp)[1][-1]/ph
A=ribbon(Lp,0,XC+3,XL,kw,kl); B=ribbon(Rp,XC-3,pw,XR,kw,kl)
# Sandals: Erika's own layered Keywi sandal (sole / straps), mapped foot-to-foot so the size ratio and position match Keywi's.
KS,KTX,KTY,KT=0.6014101796433589,-101.06716916423636,-62.09641467271149,40
K_HEEL,K_TOE,K_BOTTOM,K_MID=575.0,486.0,1108.0,476.0      # Keywi's right foot on his canvas (toes point left)
def ksrc(names):
    out=None
    for n in names:
        im=lay(f'/home/claude/kw/{n}.png'); xs=np.arange(im.shape[1])*KS+KTX; im[:,xs<K_MID,3]=0; out=im if out is None else over(out,im)
    return out
def kfit(src,flat):
    k=(390 if flat else 330)/(K_HEEL-K_TOE)
    # u = distance from heel toward toe, v = height above the foot's underside (Keywi canvas px)
    # u = K_HEEL-(KS*x+KTX), v = K_BOTTOM-(KS*y+KTY+KT)
    if flat:  M=np.float32([[-KS*k,0,195+(K_HEEL-KTX)*k+PAD],[0,KS*k,980-(K_BOTTOM-KTY-KT)*k+PAD]])           # heel x=195, toe right, underside y=980
    else:     M=np.float32([[0,-KS*k,5+(K_BOTTOM-KTY-KT)*k+PAD],[-KS*k,0,650+(K_HEEL-KTX)*k+PAD]])              # heel y=650, toe down, underside x=5
    pm=np.concatenate([src[...,:3]*src[...,3:],src[...,3:]],-1); o=cv2.warpAffine(pm,M,(W,H),flags=cv2.INTER_LINEAR); a=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/a,0,1),np.clip(o[...,3:],0,1)],-1)
KSOLE=ksrc(['sub_X39']); KSTRAP=ksrc(['sub_X42','sub_X45','sub_X46'])
S1=kfit(KSOLE,True); U1=kfit(KSTRAP,True); S2=kfit(KSOLE,False); U2=kfit(KSTRAP,False)
F2=LEGS.copy(); F2[:PAD+600]=0; F2[:,PAD+150:]=0; F2[:PAD+700,PAD+76:]=0   # the tiptoe foot alone (heel to toe, without the leg coming in from the side), in front of the straight pant leg
show([S1,LEGS,U1,A,S2,F2,U2,B],'v3.png'); show([S1,S2,LEGS,U1,U2],'v3_sandals.png'); show([LEGS,A,F2,B],'v3_pants.png')
LG=LEGS; PIE=dict(A=A,B=B,S1=S1,S2=S2,F2=F2,U1=U1,U2=U2,LG=LG)
AR='/home/claude/jamjot/app/assets/art/'
def to_canvas(x,bbox,size=1000):
    k=(bbox[2]-bbox[0])/581; M=np.float32([[k,0,bbox[0]-(PAD+4)*k],[0,k,bbox[1]-(PAD+4)*k]])
    pm=np.concatenate([x[...,:3]*x[...,3:],x[...,3:]],-1); o=cv2.warpAffine(pm,M,(size,size),flags=cv2.INTER_AREA); a=np.maximum(o[...,3:],1e-6)
    return np.concatenate([np.clip(o[...,:3]/a,0,1),o[...,3:]],-1)
def pose(tag,what):
    m=json.load(open(AR+tag+'/manifest.json')); leg=[l for l in m['layers'] if 'legs' in l][0]
    bb=Image.open(AR+tag+f'/{leg}.png').getbbox(); c=np.ones((1000,1000,4),np.float32)
    P={k:to_canvas(v,bb) for k,v in PIE.items()}
    standing='standing' in tag
    body=lay(AR+tag+f'/{m["layers"][0]}.png')[...,3]
    if 'A' in what:   # the back of the joggers shows between the legs, where his body would otherwise peek through
        k=(bb[2]-bb[0])/581; cy=int(bb[1]+(275-4)*k); pal=np.maximum(P['A'][...,3],P['B'][...,3]); g=np.zeros((1000,1000,4),np.float32)
        xs=np.nonzero(pal[cy]>0.5)[0]; reg=np.zeros((1000,1000),bool); reg[cy:,xs.min():xs.max()]=True
        g[...,:3]=np.array([150,110,72])/255; g[...,3]=cv2.GaussianBlur((cv2.dilate((body>0.5).astype(np.uint8),np.ones((5,5),np.uint8))>0).astype(np.float32)*reg,(0,0),0.7)
        P=dict(P); P['A']=over(g,P['A'])
    for l in m['layers']:
        c=over(c,lay(AR+tag+f'/{l}.png'))
        if l==leg and not standing:
            for k in what: c=over(c,P[k])
    if standing:
        for k in what: c=over(c,P[k])
    return Image.fromarray((c[...,:3]*255).astype('uint8'))
if __name__=='__main__':
    tags=['avatar_pose/jalapeno_standing','avatar_instrument/jalapeno_acoustic_guitar','avatar_instrument/jalapeno_electric_guitar','avatar_instrument/jalapeno_ukulele']
    cols=[('Plain',[]),('Serenade Sandals',['S1','S2','LG','U1','U2']),('Jazzy Joggers',['A','F2','B']),('Joggers + Sandals',['S1','LG','U1','A','S2','F2','U2','B'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22); cw=420
    Wd=Image.new('RGB',(cw*4,(cw+40)*4),'white'); d=ImageDraw.Draw(Wd)
    for r,t in enumerate(tags):
        for ci,(nm,wh) in enumerate(cols):
            Wd.paste(pose(t,wh).resize((cw,cw),Image.LANCZOS),(ci*cw,r*(cw+40)+40)); d.text((ci*cw+10,r*(cw+40)+8),t.split('jalapeno_')[1].replace('_',' ')+': '+nm,fill=(60,40,110),font=f)
    Wd.save('Presto_joggers_sandals_draft.png')
    pose(tags[0],cols[3][1]).crop((330,560,730,1000)).resize((800,880),Image.LANCZOS).save('zoom_standing.png')
