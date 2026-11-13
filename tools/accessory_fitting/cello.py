from fit2 import *
from PIL import ImageDraw, ImageFont
TAG='avatar_instrument/jalapeno_cello'
def build():
    m,leg,a=legs_of(TAG); Li,Ri=leg_info(a,True),leg_info(a,False); kw=.22; h=(XC-XL)*kw; mid=478.0; cuff=min(Li['foot_top'],Ri['foot_top'])-5
    def pts(sg):
        X=lambda x: x if sg>0 else 2*mid-x   # points given for the viewer-left leg, mirrored for the other
        return [(X(mid-h),756),(X(mid-h),784),(X(425),800),(X(372),803),(X(326),805),(X(303),826),(X(302),856),(X(304),cuff)]
    L=sum(np.hypot(*np.diff(np.array(pts(1)),axis=0).T)); kl0=L/ph*0.55
    A=ribbon(pts(1),'L',kw,kl0,(200,740,520,930)); B=ribbon(pts(-1),'R',kw,kl0,(440,740,760,930))
    g=np.zeros_like(A); poly=np.array([[mid-h,770],[mid+h,770],[mid+h+28,838],[mid-h-28,838]],np.int32); mk=np.zeros(A.shape[:2],np.uint8); cv2.fillPoly(mk,[poly],255)
    g[...,:3]=FABRIC; g[...,3]=cv2.GaussianBlur(mk.astype(np.float32)/255,(0,0),0.8); A=over(g,A)
    sL=sandal(Li['fx'][1],Li['fx'][0],Li['bot']); sR=sandal(Ri['fx'][0],Ri['fx'][1],Ri['bot'])
    return dict(m=m,leg=leg,A=A,B=B,legs_trim=trimmed_legs(a,cuff),soles=over(sL[0],sR[0]),straps=over(sL[1],sR[1]))
if __name__=='__main__':
    import apart
    P=build(); cols=[('Plain',[]),('Serenade Sandals',['sandals']),('Jazzy Joggers',['joggers']),('Joggers + Sandals',['joggers','sandals'])]
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22); cw=420; W=Image.new('RGB',(cw*4,cw+40),'white'); d=ImageDraw.Draw(W)
    for ci,(nm,wh) in enumerate(cols):
        im=apart.pose(TAG,P,wh); W.paste(im.resize((cw,cw),Image.LANCZOS),(ci*cw,40)); d.text((ci*cw+10,8),'cello: '+nm,fill=(60,40,110),font=f)
    W.save('Presto_cello_draft.png'); im.crop((200,700,760,960)).resize((1680,780),Image.LANCZOS).save('cello_zoom.png')
