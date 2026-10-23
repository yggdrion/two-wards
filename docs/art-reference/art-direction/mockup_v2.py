import random, math, sys
from PIL import Image
OUT=sys.argv[1]; HERO=sys.argv[2]
W,H=640,360
def c(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))+(255,)
GRASS=['181425','193c3e','265c42','3e8948','63c74d']
DIRT=['3e2731','733e39','b86f50','e4a672','ead4aa']
STONE=['181425','262b44','3a4466','5a6988','8b9bb4']
def vnoise(seed,scale):
    rnd=random.Random(seed); g={}
    def at(ix,iy):
        if (ix,iy) not in g: g[(ix,iy)]=rnd.random()
        return g[(ix,iy)]
    def f(x,y):
        fx,fy=x/scale,y/scale; ix,iy=int(fx),int(fy); tx,ty=fx-ix,fy-iy
        tx=tx*tx*(3-2*tx); ty=ty*ty*(3-2*ty)
        a=at(ix,iy)+(at(ix+1,iy)-at(ix,iy))*tx; b=at(ix,iy+1)+(at(ix+1,iy+1)-at(ix,iy+1))*tx
        return a+(b-a)*ty
    return f
N1=vnoise(1,16); N2=vnoise(2,9); N3=vnoise(3,14)
PATH=[(-20,262),(170,262),(170,210),(410,210),(410,186),(548,186)]
def pdist(x,y):
    best=1e9
    for (x1,y1),(x2,y2) in zip(PATH,PATH[1:]):
        dx=max(min(x1,x2)-x,0,x-max(x1,x2)); dy=max(min(y1,y2)-y,0,y-max(y1,y2))
        best=min(best,max(dx,dy))
    return best
def render(name,base_shift,lights_on):
    img=Image.new('RGBA',(W,H)); px=img.load()
    lights=[(548,170,95),(262,165,60),(330,150,50)] if lights_on else []
    lv_map={}
    for y in range(H):
        for x in range(W):
            pd=pdist(x,y)-(N2(x,y)-0.5)*7
            wall=y<54+(N3(x,0)-0.5)*8
            if wall:
                ramp=STONE; band=y//12; off=(band*17)%28
                lv=2 if (y%12==0 or (x+off)%28==0) else 3
                if y>=50+(N3(x,0)-0.5)*8: ramp=GRASS; lv=3   # grass lip on wall top edge
                lv+=base_shift
            elif pd<20:
                ramp=DIRT; lv=2+base_shift
                if pd>16: lv-=1                               # darker rim
                if N2(x*1.7,y*1.7)>0.74: lv+=1
                elif N2(x*1.3+50,y*1.3)<0.22: lv-=1
            else:
                ramp=GRASS; lv=3+base_shift
                n=N1(x,y)
                if n<0.17: lv-=1
                elif n>0.86: lv+=1
            if lights_on:
                add=0
                for lx,ly,r in lights:
                    d=math.hypot(x-lx,(y-ly)*1.35)*(0.9+0.2*N2(x+300,y))
                    a=(1 if d<r else 0)+(1 if d<r*0.4 and r>80 else 0)
                    add=max(add,a)
                lv+=add
                e=min(x,W-1-x,(y-0)*1.6,(H-1-y)*1.6)+(N2(x+77,y)-0.5)*30
                if e<34: lv-=1
            px[x,y]=c(ramp[max(0,min(4,lv))]); lv_map[(x,y)]=(ramp is GRASS,lv)
    def P(x,y,col):
        if 0<=x<W and 0<=y<H: px[x,y]=c(col)
    def ell(cx,cy,rx,ry,col):
        for y in range(int(cy-ry),int(cy+ry)+1):
            for x in range(int(cx-rx),int(cx+rx)+1):
                if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1: P(x,y,col)
    def shade(x,y,d):
        g,lv=lv_map.get((x,y),(False,0))
        return (GRASS if g else DIRT)[max(0,min(4,lv+d))]
    rnd=random.Random(5)
    # grass blades: small 'v' tufts, lighter tip, darker base
    for _ in range(2200):
        x,y=rnd.randint(2,W-3),rnd.randint(60,H-2)
        g,lv=lv_map[(x,y)]
        if not g or pdist(x,y)<22: continue
        top=GRASS[max(0,min(4,lv+1))]; P(x,y-1,top); P(x-1,y-2,top); P(x+1,y-2,top); P(x,y,GRASS[max(0,min(4,lv-1))])
    # pebbles on path
    for _ in range(140):
        x,y=rnd.randint(0,W-1),rnd.randint(60,H-2)
        if pdist(x,y)<14:
            g,lv=lv_map[(x,y)]; P(x,y,DIRT[max(0,min(4,lv+1))]); P(x+1,y,DIRT[max(0,min(4,lv+1))]); P(x,y+1,DIRT[max(0,min(4,lv-1))]); P(x+1,y+1,DIRT[max(0,min(4,lv-1))])
    # flowers
    for _ in range(40):
        x,y=rnd.randint(4,W-4),rnd.randint(70,H-4)
        if lv_map[(x,y)][0] and pdist(x,y)>26: P(x,y,rnd.choice(['fee761','ead4aa','b55088']) if base_shift==0 else rnd.choice(['feae34','c0cbdc','68386c']))
    def shadow(cx,cy,rx):
        for y in range(cy-3,cy+4):
            for x in range(cx-rx,cx+rx+1):
                if ((x-cx)/rx)**2+((y-cy)/3.2)**2<=1 and (x,y) in lv_map: P(x,y,shade(x,y,-2))
    def tree(x,y,s=1.0):
        shadow(x+6,y,int(18*s))
        k=base_shift
        for yy in range(y-int(26*s),y+1):
            for xx in range(x-3,x+3): P(xx,yy,'181425' if xx in(x-3,x+2) else ('733e39' if xx<x and k==0 else '3e2731'))
        L=[GRASS[max(0,1+k)],GRASS[max(0,2+k)],GRASS[max(0,3+k)],GRASS[min(4,4+k)]]
        cy=y-int(40*s)
        for dx,dy,r in [(-12,6,13),(12,6,13),(0,-4,17),(-8,-10,11),(8,-12,10)]:
            ell(x+dx*s,cy+dy*s,(r+1)*s,(r)*s*0.9,'181425')
        for dx,dy,r in [(-12,6,13),(12,6,13),(0,-4,17),(-8,-10,11),(8,-12,10)]:
            ell(x+dx*s,cy+dy*s,r*s,(r-1)*s*0.9,L[1])
        for dx,dy,r in [(-13,3,8),(-2,-8,11),(-9,-13,7),(6,-15,6)]:
            ell(x+dx*s,cy+dy*s,r*s,(r-1)*s*0.9,L[2])
        for dx,dy,r in [(-5,-13,5),(-12,-1,4),(3,-18,3)]:
            ell(x+dx*s,cy+dy*s,r*s,(r-1)*s*0.9,L[3])
        for dx,dy,r in [(10,10,6),(14,4,4)]:
            ell(x+dx*s,cy+dy*s,r*s,(r-1)*s*0.9,L[0])
    def rock(x,y,s=1):
        shadow(x+3,y+2,int(10*s)); ell(x,y,10*s,7*s,'181425'); ell(x,y,9*s,6*s,STONE[2+base_shift]); ell(x-2*s,y-2*s,5*s,3*s,STONE[3+base_shift]); ell(x+4*s,y+2*s,4*s,2*s,STONE[1+base_shift] if base_shift==0 else STONE[1])
    def bush(x,y):
        shadow(x+3,y,11); ell(x,y-6,11,8,'181425'); ell(x,y-6,10,7,GRASS[2+base_shift]); ell(x-3,y-9,5,3,GRASS[3+base_shift]); ell(x+4,y-3,4,3,GRASS[1+base_shift])
    objs=[('tree',60,140,1.1),('tree',610,120,1.0),('tree',110,345,1.2),('tree',505,345,1.1),('tree',335,350,0.9),
          ('rock',95,195,1),('rock',255,320,1),('rock',470,265,1),('rock',600,250,0.8),('bush',210,170,0),('bush',380,290,0),('bush',30,300,0),('bush',560,300,0)]
    # tower
    def tower(x,y):
        shadow(x+4,y,15); S=STONE
        for yy in range(y-52,y+1):
            for xx in range(x-12,x+12):
                edge=xx in(x-12,x+11)
                col='181425' if edge else (S[3] if xx<x-4 else S[2] if xx<x+5 else S[1])
                if not edge and (yy-y)%7==0: col=S[1] if xx<x+5 else S[0]
                if not edge and ((yy-y)//7)%2==0 and xx==x and (yy-y)%7: col=S[1]
                P(xx,yy,col)
        for yy in range(y-60,y-51):
            for xx in range(x-15,x+15): P(xx,yy,'181425' if xx in(x-15,x+14) or yy==y-60 else (S[4] if yy<y-56 else S[3]))
        for bx in (x-14,x-5,x+5):
            for yy in range(y-66,y-60):
                for xx in range(bx,bx+8): P(xx,yy,'181425' if xx in(bx,bx+7) or yy==y-66 else S[3])
        ell(x,y-71,4,6,'181425'); ell(x,y-71,3,5,'0099db'); P(x-1,y-74,'ffffff'); P(x-1,y-73,'2ce8f5')
    def crystal(x,y):
        shadow(x+3,y+4,16)
        ell(x,y+1,16,5,'181425'); ell(x,y,15,4,STONE[3]); ell(x,y-1,12,3,STONE[4])  # pedestal
        top=y-58
        for i in range(52):
            w=int(13*(i/22)) if i<22 else int(13*(1-(i-22)/34))
            for xx in range(x-w-1,x+w+2): P(xx,top+i,'181425')
        for i in range(1,51):
            w=int(13*(i/22)) if i<22 else int(13*(1-(i-22)/34))
            for xx in range(x-w,x+w+1):
                col='2ce8f5' if xx<x-w//3 else ('0099db' if xx<x+w//3 else '124e89')
                P(xx,top+i,col)
        for i in range(6,26): P(x-6+i//6,top+i,'ffffff')
        rnd2=random.Random(9)
        for k in range(18):
            a=rnd2.random()*6.28; r=22+rnd2.random()*30
            P(int(x+math.cos(a)*r),int(y-30+math.sin(a)*r*0.8),rnd2.choice(['2ce8f5','ffffff','0099db']))
    def goblin(x,y):
        shadow(x,y,8)
        ell(x,y-9,8,9,'181425'); ell(x,y-9,7,8,'3e8948'); ell(x-2,y-12,3,3,'63c74d'); ell(x+3,y-5,3,2,'265c42')
        for s in(-1,1):
            for i in range(4): P(x+s*(8+i),y-14-i//2,'181425'); P(x+s*(8+i),y-13-i//2,'3e8948')
        P(x-3,y-10,'e43b44'); P(x+2,y-10,'e43b44'); P(x-3,y-11,'f77622'); P(x+2,y-11,'f77622')
    draw=[]
    for kind,x,y,s in objs: draw.append((y,kind,x,s))
    draw+= [(186,'tower',330,0),(185,'crystal',548,0),(265,'gob',95,0),(260,'gob',125,0),(213,'gob',460,0),(180,'hero',262,0)]
    hero=Image.open(HERO).convert('RGBA').crop((0,0,64,64))
    for y,kind,x,s in sorted(draw):
        if kind=='tree': tree(x,y,s)
        elif kind=='rock': rock(x,y,s)
        elif kind=='bush': bush(x,y)
        elif kind=='tower': tower(x,y)
        elif kind=='crystal': crystal(x,y)
        elif kind=='gob': goblin(x,y)
        elif kind=='hero':
            shadow(x,y,12); img.alpha_composite(hero,(x-32,y-60))
            if lights_on:
                for k in range(5): P(x+19+int(math.cos(k*1.3)*5),y-52+int(math.sin(k*2.1)*5),'2ce8f5' if k%2 else 'ffffff')
    img.resize((W*2,H*2),Image.NEAREST).save(f'{OUT}/{name}.png')
render('evening_a_lit',-1,True)
render('evening_b_late_afternoon',0,False)
