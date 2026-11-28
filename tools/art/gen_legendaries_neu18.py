import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from px import Canvas, ellipse_mask, poly_mask, union, minus, PALETTE
from PIL import Image, ImageDraw, ImageFont

S = 80
TONES = {"light": (3, 2, 3), "mid": (2, 1, 3), "dark": (1, 0, 2), "ink": (0, 0, 1), "flat0": (0, 0, 0), "flat3": (3, 3, 3)}

class Part:
    def __init__(s, mask, tone="mid", outline=True, shade=True):
        s.mask, s.tone, s.outline, s.shade = mask, tone, outline, shade
class Stamp:
    def __init__(s, x, y, rows): s.x, s.y, s.rows = x, y, rows

def mir(pts): return [(S - x, y) for x, y in pts]
def P(pts, tone="mid", sym=False, **kw):
    m = poly_mask(pts)
    if sym: m = union(m, poly_mask(mir(pts)))
    return Part(m, tone, **kw)
def E(cx, cy, rx, ry, tone="mid", sym=False, **kw):
    m = ellipse_mask(cx, cy, rx, ry)
    if sym: m = union(m, ellipse_mask(S - cx, cy, rx, ry))
    return Part(m, tone, **kw)
def RING(cx, cy, r, w, tone="light", **kw):
    return Part(minus(ellipse_mask(cx, cy, r, r), ellipse_mask(cx, cy, r - w, r - w)), tone, **kw)
def ST(x, y, rows, sym=False):
    out = [Stamp(x, y, rows)]
    if sym: out.append(Stamp(S - x - len(rows[0]), y, [r[::-1] for r in rows]))
    return out
def LINE(x0, y0, x1, y1, v=0, sym=False):
    rows = []
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    pts = {(round(x0 + (x1 - x0) * i / max(n - 1, 1)), round(y0 + (y1 - y0) * i / max(n - 1, 1))) for i in range(n)}
    if sym: pts |= {(S - 1 - x, y) for x, y in pts}
    return Dots(pts, v)
class Dots:
    def __init__(s, pts, v): s.pts, s.v = pts, v

def render(parts):
    c = Canvas(S, S)
    flat = []
    for p in parts:
        flat.extend(p if isinstance(p, list) else [p])
    for part in flat:
        if isinstance(part, Stamp):
            c.ascii(part.x, part.y, part.rows); continue
        if isinstance(part, Dots):
            for x, y in part.pts: c.set(x, y, part.v)
            continue
        ins_ = [[part.mask(x, y) for x in range(S)] for y in range(S)]
        ins = lambda x, y: 0 <= x < S and 0 <= y < S and ins_[y][x]
        base, sh, hi = TONES[part.tone]
        if part.outline:
            for y in range(S):
                for x in range(S):
                    if not ins_[y][x] and (ins(x-1,y) or ins(x+1,y) or ins(x,y-1) or ins(x,y+1)):
                        c.set(x, y, 0)
        for y in range(S):
            for x in range(S):
                if not ins_[y][x]: continue
                v = base
                if part.shade:
                    if not ins(x+1, y+1) or not ins(x+1, y): v = sh
                    elif not ins(x+2, y+2) and (x+y) % 2 == 0: v = sh
                    elif not ins(x-1, y-1) or not ins(x, y-1): v = hi
                c.set(x, y, v)
    return c

EYE = [".00.", "0330", "0300", "0000", ".00."]
EYE_S = ["000", "033", "000"]
GLOW = ["0000", "0333", "0000"]
def eyes(x, y, rows=EYE): return ST(x, y, rows, sym=True)
def ground(y=74, rx=22): return E(40, y, rx, 3, "dark")

# ---------------- designs ----------------
def pyrecrest():  # Ember
    return [ground(),
        P([(40,4),(46,14),(52,6),(54,18),(62,10),(60,24),(68,22),(62,34),(40,30)], "light", sym=True),  # flame mane
        P([(40,10),(44,18),(50,14),(50,26),(40,26)], "mid", sym=True, outline=False),
        P([(52,56),(66,46),(72,36),(70,50),(60,62)], "mid"),  # tail
        P([(70,32),(76,28),(74,40),(68,40)], "light"),
        E(40,54,17,15,"mid"), E(40,58,9,10,"light"),
        E(30,70,6,4,"dark",sym=True),
        E(40,32,12,11,"mid"), P([(34,36),(46,36),(43,44),(37,44)],"light"),
        P([(28,22),(24,12),(32,20)],"dark",sym=True),  # horns
        eyes(32,28,GLOW), ST(38,40,["0..0",".00."]), ST(39,46,["00"]),
    ]

def cindralis():  # Ember moth
    return [
        P([(40,30),(8,8),(4,30),(14,40),(40,40)],"mid",sym=True),
        P([(40,40),(14,44),(10,62),(24,66),(40,48)],"dark",sym=True),
        E(18,24,6,6,"light",sym=True), E(20,56,4,4,"light",sym=True),
        P([(40,8),(36,20),(44,20)],"light"),
        P([(36,18),(30,4),(28,6),(34,20)],"dark",sym=True,outline=False),
        E(40,44,6,22,"mid"), E(40,26,7,6,"light"),
        ST(36,25,["0..0"]) , ST(37,24,["3"]), ST(42,24,["3"]),
        ST(37,40,["0000"]), ST(37,46,["0000"]), ST(37,52,["0000"]),
        P([(38,66),(40,76),(42,66)],"light"),
    ]

def thalassor():  # Tide serpent whale
    return [
        E(40,70,30,6,"dark"),
        P([(14,70),(10,50),(20,40),(30,60),(26,70)],"mid"),
        P([(66,70),(70,50),(64,38),(54,60),(54,70)],"mid"),
        P([(70,50),(78,40),(76,56)],"light"),
        E(40,46,14,22,"mid"), E(40,52,8,14,"light"),
        P([(26,30),(10,22),(16,38),(28,40)],"light",sym=True),  # fins
        E(40,22,13,11,"mid"),
        P([(40,4),(44,12),(40,14),(36,12)],"light"),
        eyes(31,20,EYE), ST(36,30,["00000000"]), ST(34,29,["0"]), ST(45,29,["0"]),
        ST(38,44,["3.3"]), ST(38,56,["3.3"]),
    ]

def mareveil():  # Tide jelly queen
    out = [P([(20,40),(60,40),(64,48),(16,48)],"dark")]
    for i, x in enumerate([18,26,34,46,54,62]):
        out.append(P([(x-2,44),(x+2,44),(x+3+(i%2)*2,62),(x+(i%3)-1,76),(x-3,60)],"mid"))
    out += [E(40,30,24,18,"light"), E(40,36,16,8,"mid",outline=False),
        P([(30,12),(34,2),(40,10),(46,2),(50,12)],"mid"),
        eyes(32,32,EYE_S), ST(38,40,[".00.","0..0"]),
        E(24,22,3,3,"flat3",sym=True)]
    return out

def verdaneth():  # Bloom stag
    return [ground(74,18),
        LINE(34,22,22,6,1,sym=True), LINE(28,14,20,14,1,sym=True), LINE(24,9,28,2,1,sym=True),
        E(20,6,3,3,"light",sym=True), E(18,14,3,3,"light",sym=True), E(28,2,2,2,"light",sym=True),
        E(32,64,4,10,"dark",sym=True),
        E(40,52,15,14,"mid"), E(40,46,8,8,"light"),
        E(40,30,9,10,"mid"), P([(36,36),(44,36),(42,44),(38,44)],"light"),
        P([(30,26),(20,22),(30,32)],"mid",sym=True),
        eyes(33,28,EYE_S), ST(39,42,["00"]),
        E(34,52,2,2,"flat3"), E(46,56,2,2,"flat3"), E(40,60,2,2,"flat3"),
    ]

def petalune():  # Bloom lotus guardian
    return [ground(74,26),
        P([(40,60),(6,50),(16,70),(40,72)],"mid",sym=True),
        P([(40,62),(18,36),(24,64)],"light",sym=True),
        P([(40,60),(28,26),(40,18),(52,26)],"light"),
        E(40,44,10,12,"mid"),
        eyes(33,40,EYE_S), ST(38,50,["0..0",".00."]),
        E(40,14,4,4,"flat3"), E(40,14,2,2,"flat0",outline=False),
        P([(40,66),(34,74),(46,74)],"dark"),
    ]

def fulgrath():  # Volt ram
    return [ground(),
        P([(32,26),(18,14),(10,24),(14,38),(22,36),(18,28),(22,22),(30,32)],"light",sym=True),  # curled horns
        P([(18,14),(12,4),(18,8),(16,0),(24,12)],"light",sym=True),  # spark tips
        E(40,56,18,14,"mid"), E(40,54,12,9,"light"),
        E(30,70,6,4,"dark",sym=True),
        E(40,32,12,12,"mid"), P([(34,38),(46,38),(42,48),(38,48)],"dark"),
        P([(40,20),(37,28),(41,28),(38,36),(45,26),(41,26),(43,20)],"flat3"),
        eyes(31,30,GLOW), ST(38,44,["0..0"]),
        LINE(22,54,30,60,0,sym=True),
    ]

def zirrakai():  # Volt coil serpent
    return [E(40,72,22,4,"dark"),
        Part(minus(ellipse_mask(40,60,22,12),ellipse_mask(40,60,12,6)),"mid"),
        Part(minus(ellipse_mask(40,46,16,9),ellipse_mask(40,46,7,4)),"mid"),
        E(40,30,8,12,"mid"),
        E(40,20,11,9,"mid"),
        P([(32,14),(22,0),(26,2),(34,10)],"light",sym=True),
        P([(40,12),(37,2),(43,2)],"light"),
        eyes(31,18,GLOW), ST(36,26,["0000000"]),
        E(18,60,2,2,"flat3",sym=True), E(26,46,2,2,"flat3",sym=True),
        LINE(22,32,14,24,0,sym=True), LINE(14,24,18,22,0,sym=True), LINE(18,22,10,14,0,sym=True),
    ]

def monolurk():  # Stone monolith
    return [ground(75,24),
        P([(26,8),(54,8),(58,72),(22,72)],"dark"),
        P([(22,30),(10,36),(8,56),(16,58),(22,46)],"mid",sym=True),
        E(12,60,6,5,"mid",sym=True),
        P([(28,12),(52,12),(54,26),(26,26)],"mid"),
        E(40,19,6,5,"flat3"), E(40,19,3,3,"flat0",outline=False), ST(40,18,["3"]),
        LINE(40,32,40,62,0), LINE(32,40,48,40,0), LINE(34,52,46,52,0), LINE(30,30,34,36,0,sym=True),
        LINE(26,64,34,58,2), LINE(54,64,46,58,2),
    ]

def graventh():  # Stone tortoise mountain
    return [ground(74,30),
        E(20,66,7,6,"dark",sym=True),
        E(40,52,30,18,"mid"),
        P([(40,14),(52,34),(60,42),(20,42),(28,34)],"dark"),
        P([(40,14),(46,24),(34,24)],"flat3"),
        P([(24,28),(18,40),(30,40)],"dark",sym=True),
        LINE(20,52,60,52,0), LINE(30,44,26,62,0), LINE(50,44,54,62,0), LINE(40,44,40,64,0),
        E(40,62,10,8,"light"),
        eyes(34,60,EYE_S), ST(37,66,["000000"]),
    ]

def zephyrel():  # Gale four-winged kite bird
    return [
        P([(40,30),(2,10),(10,24),(4,30),(36,38)],"light",sym=True),
        P([(40,42),(6,52),(14,56),(10,62),(38,50)],"mid",sym=True),
        LINE(10,20,30,32,1,sym=True), LINE(14,55,32,48,1,sym=True),
        P([(36,56),(28,76),(40,68),(52,76),(44,56)],"mid"),
        E(40,44,9,14,"mid"), E(40,46,5,9,"light"),
        E(40,24,8,8,"light"),
        P([(38,28),(42,28),(40,34)],"dark"),
        P([(36,18),(30,4),(40,14),(50,4),(44,18)],"mid"),
        eyes(34,22,EYE_S),
    ]

def lumivane():  # Lumen lantern deer
    return [ground(),
        RING(40,18,16,2,"light"),
        P([(34,20),(28,8),(32,8),(36,18)],"light",sym=True),
        E(32,64,4,10,"dark",sym=True),
        E(40,52,15,13,"light"),
        E(40,54,6,7,"flat3"), E(40,54,3,4,"mid",outline=False),
        E(40,30,9,9,"light"), P([(36,36),(44,36),(42,42),(38,42)],"mid"),
        eyes(33,28,EYE_S), ST(39,40,["00"]),
        LINE(40,58,40,62,0),
    ]

def noctharn():  # Umbra hooded wolf
    return [ground(75,26),
        P([(40,6),(62,26),(70,70),(10,70),(18,26)],"dark"),
        P([(18,70),(22,62),(28,72),(34,62),(40,72),(46,62),(52,72),(58,62),(62,70)],"ink",outline=False),
        P([(28,16),(24,4),(34,12)],"dark",sym=True),
        E(40,32,14,13,"ink"),
        eyes(30,28,GLOW),
        ST(34,38,["0.3.3.3.0"]) ,
        LINE(28,50,40,60,1), LINE(52,50,40,60,1),
        E(40,52,3,3,"light"),
    ]

def vorlucent():  # Umbra eclipse moth
    return [
        P([(40,30),(4,6),(6,40),(40,44)],"ink",sym=True),
        P([(40,44),(12,50),(16,70),(40,56)],"dark",sym=True),
        RING(18,24,6,2,"light"), RING(62,24,6,2,"light"),
        LINE(10,14,30,34,1,sym=True),
        E(40,46,7,22,"dark"),
        E(40,24,9,8,"ink"),
        P([(34,18),(26,4),(36,14)],"dark",sym=True),
        eyes(33,22,GLOW),
        RING(40,46,5,2,"light"),
    ]

def scriptorax():  # Ink quill drake
    return [E(40,74,26,4,"ink"),
        P([(40,28),(6,10),(14,22),(4,26),(16,34),(8,40),(36,44)],"dark",sym=True),
        LINE(8,12,34,36,3,sym=True), LINE(6,26,30,40,3,sym=True),
        P([(30,60),(24,74),(34,70),(40,76),(46,70),(56,74),(50,60)],"ink"),
        E(40,52,12,16,"dark"), E(40,54,6,10,"mid"),
        E(40,26,9,10,"dark"),
        P([(40,4),(43,14),(40,18),(37,14)],"light"),
        eyes(32,24,EYE_S), ST(37,32,["000000"]),
        E(34,70,1.5,3,"ink",sym=True),
    ]

def resonyx():  # Echo bat with fork horns
    return [
        RING(40,40,38,1,"dark",outline=False), RING(40,40,32,1,"mid",outline=False),
        P([(40,30),(4,20),(10,34),(6,48),(16,44),(18,56),(38,50)],"dark",sym=True),
        LINE(8,24,34,38,1,sym=True), LINE(16,48,34,46,1,sym=True),
        E(40,46,10,14,"mid"), E(40,48,5,8,"light"),
        E(40,26,10,9,"mid"),
        P([(32,22),(30,4),(34,4),(35,20)],"light",sym=True),
        P([(30,4),(34,4),(34,8),(30,8)],"flat3",sym=True,outline=False),
        eyes(33,24,EYE_S), ST(37,32,["0.00.0"]),
        E(34,62,3,4,"dark",sym=True),
    ]

def hallowmur():  # Echo bell spirit
    return [ground(75,20),
        RING(40,46,30,1,"mid",outline=False),
        P([(40,8),(54,18),(58,50),(66,64),(14,64),(22,50),(26,18)],"light"),
        P([(16,64),(64,64),(62,68),(18,68)],"mid"),
        E(40,6,4,4,"mid"),
        E(40,70,5,4,"dark"),
        P([(18,40),(6,30),(4,46),(18,52)],"mid",sym=True),
        E(40,32,9,8,"flat0"),
        eyes(33,29,["000","033","000"]), ST(38,36,[".33.",]),
        LINE(30,50,50,50,2),
    ]

def solmira():  # Lumen sun owl
    out = []
    for i in range(12):
        a = i * math.pi / 6
        out.append(LINE(40+round(math.cos(a)*24),34+round(math.sin(a)*24),40+round(math.cos(a)*32),34+round(math.sin(a)*32),2))
    out += [RING(40,34,22,2,"light"),
        P([(24,44),(10,58),(26,62)],"mid",sym=True),
        E(40,46,15,18,"mid"), E(40,50,9,11,"light"),
        LINE(34,46,40,50,1), LINE(46,46,40,50,1), LINE(34,54,40,58,1), LINE(46,54,40,58,1),
        E(40,28,13,10,"mid"),
        RING(33,28,5,2,"light"), RING(47,28,5,2,"light"),
        ST(32,27,["03","00"]), ST(46,27,["03","00"]),
        P([(38,32),(42,32),(40,37)],"light"),
        E(34,66,3,3,"dark",sym=True)]
    return out

def cindhorn():  # Ember volcano boar? -> use Gale second instead
    return []

def vaelstrom():  # Gale whirl serpent
    return [
        RING(40,46,30,2,"light"), RING(40,46,22,2,"mid"), RING(40,46,14,2,"light"),
        E(40,46,8,12,"mid"),
        E(40,24,11,9,"mid"),
        P([(30,22),(10,10),(28,28)],"light",sym=True),
        P([(40,14),(36,2),(44,2)],"light"),
        eyes(32,22,EYE_S), ST(38,30,["0000"]),
        P([(36,56),(40,76),(44,56)],"mid"),
    ]

D = [
 ("pyrecrest","Ember","Flame-maned lion sovereign whose crest flares when it roars",pyrecrest),
 ("cindralis","Ember","Ember moth whose wingbeats scatter slow-burning cinders",cindralis),
 ("thalassor","Tide","Deep-sea leviathan that rises with the spring tides",thalassor),
 ("mareveil","Tide","Veiled jelly matriarch trailing tidal tendrils",mareveil),
 ("verdaneth","Bloom","Stag whose antlers flower in its wake",verdaneth),
 ("petalune","Bloom","Lotus guardian sleeping inside a ring of giant petals",petalune),
 ("fulgrath","Volt","Storm ram with coiled horns that arc lightning",fulgrath),
 ("zirrakai","Volt","Coiled spark serpent that charges the air around it",zirrakai),
 ("monolurk","Stone","Rune-scored monolith that wakes with a single eye",monolurk),
 ("graventh","Stone","Ancient tortoise carrying a snow-capped peak",graventh),
 ("zephyrel","Gale","Four-winged sky kite riding high currents",zephyrel),
 ("vaelstrom","Gale","Serpent at the eye of a living whirlwind",vaelstrom),
 ("lumivane","Lumen","Haloed deer with a lantern heart",lumivane),
 ("solmira","Lumen","Sun-wheel owl that watches the dawn",solmira),
 ("noctharn","Umbra","Hooded shade wolf of the long night",noctharn),
 ("vorlucent","Umbra","Eclipse moth with ringed eyespots",vorlucent),
 ("scriptorax","Ink","Quill-winged drake that writes in dripping ink",scriptorax),
 ("resonyx","Echo","Fork-horned bat ringed by its own sound waves",resonyx),
]
# swap one Echo in? keep Hallowmur by replacing nothing; add as Echo second via vorlucent? see list
D[15] = D[15]
D.append(("hallowmur","Echo","Bell spirit whose toll lingers for days",hallowmur))
D.pop(13)  # drop solmira -> keep 18

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    only = sys.argv[2:] 
    for i,(n,el,c,f) in enumerate(D,1):
        if only and n not in only: continue
        im = render(f()).image()
        im.save(f"{out}/{n}_native.png"); im.resize((480,480),Image.NEAREST).save(f"{out}/{n}.png")
    # overview
    cols, cw, ch = 6, 336, 400
    sheet = Image.new("RGB",(cols*cw+40, 3*ch+80),(0xE8,0xDC,0xC4))
    d = ImageDraw.Draw(sheet)
    try:
        fb = ImageFont.truetype("DejaVuSans-Bold.ttf",22); fs = ImageFont.truetype("DejaVuSans.ttf",16)
    except Exception: fb = fs = ImageFont.load_default()
    d.text((20,20),"Chimora - 18 neue Legendaere (80x80 nativ, 4x)",fill=PALETTE[0],font=fb)
    for i,(n,el,c,f) in enumerate(D):
        x, y = 20 + (i%cols)*cw, 70 + (i//cols)*ch
        im = Image.open(f"{out}/{n}_native.png").resize((320,320),Image.NEAREST)
        sheet.paste(im,(x,y),im)
        d.text((x,y+326),f"{i+1}. {n.capitalize()}",fill=PALETTE[0],font=fb)
        d.text((x,y+354),el,fill=PALETTE[1],font=fs)
    sheet.save(f"{out}/uebersicht.png")
    print(len(D))
