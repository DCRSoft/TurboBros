import sys, os, numpy as np, cv2
sys.path.insert(0, os.path.dirname(__file__))
from tracks_px import R, T
def cat(p0,p1,p2,p3,t):
    return tuple(0.5*((2*p1[i])+(-p0[i]+p2[i])*t+(2*p0[i]-5*p1[i]+4*p2[i]-p3[i])*t*t+(-p0[i]+3*p1[i]-3*p2[i]+p3[i])*t**3) for i in range(2))
def curve(P):
    n=len(P); out=[]
    for i in range(n):
        for s in range(12): out.append(cat(P[i-1],P[i],P[(i+1)%n],P[(i+2)%n],s/12))
    return out
def main(ids):
    img=cv2.imread('F:/Dev/pistas.png')
    tiles=[]
    for k in ids:
        x,y,w,h=R[k]; c=cv2.resize(img[y:y+h,x:x+w],None,fx=3,fy=3,interpolation=cv2.INTER_CUBIC)
        cv=curve(T[k]); pts=np.array([[int(a*3),int(b*3)] for a,b in cv],np.int32)
        cv2.polylines(c,[pts],True,(0,255,255),2)
        for i,(a,b) in enumerate(T[k]):
            cv2.circle(c,(int(a*3),int(b*3)),3,(255,0,255),-1)
        a,b=T[k][0]; cv2.circle(c,(int(a*3),int(b*3)),8,(0,0,255),-1)
        a2,b2=T[k][2]; cv2.arrowedLine(c,(int(a*3),int(b*3)),(int(a2*3),int(b2*3)),(0,255,0),3,tipLength=0.5)
        cv2.imwrite(os.environ['TEMP']+f'/ov{k}.png',c)
if __name__=='__main__': main([int(a) for a in sys.argv[1:]] or list(T))
