from fit2 import *
from PIL import ImageDraw, ImageFont
def build(tag,kw_base=.22,waist_off=-8):
    m,leg,a=legs_of(tag); bb=Image.open(AR+tag+f'/{leg}.png').getbbox(); sc=(bb[3]-bb[1])/191
    A,B,crotch,(Li,Ri),cuff=joggers_two_legs(a,kw_base*sc,bb[1]+waist_off*sc)
    body=lay(AR+tag+f'/{m["layers"][0]}.png')[...,3]; A=gusset(A,B,body,crotch)
    sL=sandal(Li['fx'][1],Li['fx'][0],Li['bot']); sR=sandal(Ri['fx'][0],Ri['fx'][1],Ri['bot'])     # feet point outward
    return dict(m=m,leg=leg,A=A,B=B,legs_trim=trimmed_legs(a,cuff),soles=over(sL[0],sR[0]),straps=over(sL[1],sR[1]))
def pose(tag,P,what):
    m=P['m']; ls=[]
    for l in m['layers']:
        if l==P['leg'] and 'sandals' in what: ls.append(P['soles'])
        ls.append(P['legs_trim'] if (l==P['leg'] and 'joggers' in what) else lay(AR+tag+f'/{l}.png'))
        if l==P['leg']:
            if 'sandals' in what: ls.append(P['straps'])
            if 'joggers' in what: ls+= [P['A'],P['B']]
    return img(flat(ls))
if __name__=='__main__':
    tags=['avatar_instrument/jalapeno_'+n for n in ['violin','viola','double_bass','flute','piano']]
    cols=[('Plain',[]),('Serenade Sandals',['sandals']),('Jazzy Joggers',['joggers']),('Joggers + Sandals',['joggers','sandals'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22); cw=420
    W=Image.new('RGB',(cw*4,(cw+40)*len(tags)),'white'); d=ImageDraw.Draw(W); zooms=[]
    for r,t in enumerate(tags):
        P=build(t)
        for ci,(nm,wh) in enumerate(cols):
            im=pose(t,P,wh); W.paste(im.resize((cw,cw),Image.LANCZOS),(ci*cw,r*(cw+40)+40)); d.text((ci*cw+10,r*(cw+40)+8),t.split('jalapeno_')[1].replace('_',' ')+': '+nm,fill=(60,40,110),font=f)
        if 'violin' in t or 'piano' in t or 'flute' in t:
            bb=Image.open(AR+t+f'/{P["leg"]}.png').getbbox(); zooms.append(im.crop((bb[0]-40,bb[1]-60,bb[2]+40,bb[3]+30)).resize((700,int(700*(bb[3]-bb[1]+90)/(bb[2]-bb[0]+80))),Image.LANCZOS))
    W.save('Presto_apart_legs_draft.png')
    Z=Image.new('RGB',(sum(z.width for z in zooms)+20,max(z.height for z in zooms)),'white'); x=0
    for z in zooms: Z.paste(z,(x,0)); x+=z.width+10
    Z.save('apart_zoom.png')
