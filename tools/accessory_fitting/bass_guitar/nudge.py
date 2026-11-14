import numpy as np, cv2
def nudge_upper(tip,inst_alpha,cap=70):
    """Swing the upper fingertip round the lower one (same spacing as before) until it hangs off the neck's edge about as much as the lower one."""
    n,lab,st,cen=cv2.connectedComponentsWithStats((tip[...,3]>0.5).astype(np.uint8)); ids=sorted(range(1,n),key=lambda i:-st[i,4])[:2]
    if len(ids)<2: return tip,0
    up,lo=sorted(ids,key=lambda i:cen[i][1]); off=lambda m: float((m&~inst_alpha).sum())/max(m.sum(),1); target=off(lab==lo); mu=lab==up; v=cen[up]-cen[lo]
    for deg in range(0,cap+1,2):
        t=np.radians(deg); nv=np.array([np.cos(t)*v[0]-np.sin(t)*v[1],np.sin(t)*v[0]+np.cos(t)*v[1]]); d=np.round(nv-v).astype(int)      # clockwise on screen
        if off(np.roll(np.roll(mu,d[0],axis=1),d[1],axis=0))>=target*0.9: break
    piece=tip*mu[...,None]; sh=np.roll(np.roll(piece,d[0],axis=1),d[1],axis=0); out=tip.copy(); out[...,3]*=~mu; a=sh[...,3:]; res=sh*a+out*(1-a); res[...,3]=np.maximum(sh[...,3],out[...,3]); return res,(deg,d.tolist())
