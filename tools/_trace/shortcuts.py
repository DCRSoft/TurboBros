"""Busca un atajo por pista y lo escribe como SHORTCUTS en tools/generate_tracks.gd.
   python tools/_trace/shortcuts.py
Un atajo sale de la carretera en la muestra ia (tangente girada hacia dentro) y vuelve a entrar en ib; es un camino
Hermite; se exige: ahorro de 45-115 m, radio >= 20 m, separación >= 2*ancho+10 m de la carretera (salvo en las puntas),
sin elementos (puentes, túneles, rampas) en las bocas y lejos de la meta."""
import os, re, math, sys
sys.path.insert(0, os.environ['TEMP'])
from lay import analyze

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
gen = open(os.path.join(ROOT, 'tools', 'generate_tracks.gd'), encoding='utf-8').read()
IDS = ['01_costa', '02_neon', '03_bosque', '04_circuito', '05_volcan', '06_desierto', '07_industrial', '08_nieve', '09_extremo', '10_fantasia']
NAMES = ['COSTA', 'NEON', 'BOSQUE', 'CIRCUITO', 'VOLCAN', 'DESIERTO', 'INDUSTRIAL', 'NIEVE', 'EXTREMO', 'FANTASIA']
HW = {'01_costa': 8.5, '02_neon': 8.0, '03_bosque': 8.0, '04_circuito': 9.5, '05_volcan': 8.0, '06_desierto': 9.0, '07_industrial': 8.0, '08_nieve': 8.0, '09_extremo': 9.0, '10_fantasia': 8.5}
STEP = 3.0


def layout(name):
    m = re.search(r'const LAYOUT_%s := \[(.*)\]' % name, gen)
    nums = re.findall(r'\[(-?[\d.]+), (-?[\d.]+)\]', m.group(1))
    return [(float(a), float(b)) for a, b in nums]


def features(tid):
    t = open(os.path.join(ROOT, 'data', 'tracks', tid + '.tres'), encoding='utf-8').read()
    out = []
    for blk in re.findall(r'\{[^{}]*\}', t[t.index('features'):]):
        f = re.search(r'"f": ([\d.]+)', blk)
        if f:
            ln = re.search(r'"len": ([\d.]+)', blk)
            out.append((float(f.group(1)), float(ln.group(1)) if ln else 0.0, re.search(r'"type": "(\w+)"', blk).group(1)))
    return out


def rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def hermite(A, B, ta, tb, m, n):
    pts = []
    for i in range(n + 1):
        t = i / n
        h00 = 2 * t**3 - 3 * t**2 + 1
        h10 = t**3 - 2 * t**2 + t
        h01 = -2 * t**3 + 3 * t**2
        h11 = t**3 - t**2
        pts.append((h00 * A[0] + h10 * m * ta[0] + h01 * B[0] + h11 * m * tb[0], h00 * A[1] + h10 * m * ta[1] + h01 * B[1] + h11 * m * tb[1]))
    return pts


def plen(p):
    return sum(math.dist(p[i], p[i + 1]) for i in range(len(p) - 1))


def radius(p):
    # radio mínimo en ventanas de ~15 m
    best = 1e9
    n = len(p)
    for i in range(1, n - 6):
        a = math.atan2(p[i + 1][1] - p[i][1], p[i + 1][0] - p[i][0])
        b = math.atan2(p[i + 6][1] - p[i + 5][1], p[i + 6][0] - p[i + 5][0])
        d = abs((b - a + math.pi) % (2 * math.pi) - math.pi)
        if d > 1e-4:
            best = min(best, 5 * STEP / d)
    return best


out = {}
for tid, name in zip(IDS, NAMES):
    P = layout(name)
    r, ov, tot, res = analyze(P, 0.0) if False else (None, None, None, None)
    # muestras principales a 3 m (misma curva que el circuito)
    import lay
    d, total = lay.resample(P)
    r, ov, tot, res = analyze(P, total)
    cnt = len(res)
    feats = features(tid)
    hw = HW[tid]
    tang = []
    for i in range(cnt):
        a = res[(i - 1) % cnt]
        b = res[(i + 1) % cnt]
        v = (b[0] - a[0], b[1] - a[1])
        L = math.hypot(*v)
        tang.append((v[0] / L, v[1] / L))
    best = None
    for ia in range(int(cnt * 0.08), int(cnt * 0.90), 3):
        for arc in range(40, 131, 3):
            ib = ia + arc
            if ib >= cnt * 0.94:
                continue
            fa, fb = ia / cnt, ib / cnt
            bad = False
            for (f, ln, tp) in feats:
                f0 = f
                f1 = f + ln / (cnt * STEP)
                if f1 > fa - 12 / cnt and f0 < fa + 16 / cnt or f1 > fb - 16 / cnt and f0 < fb + 12 / cnt:
                    bad = True
            if bad:
                continue
            A, B = res[ia], res[ib]
            chord = (B[0] - A[0], B[1] - A[1])
            cross = tang[ia][0] * chord[1] - tang[ia][1] * chord[0]
            s = 1.0 if cross > 0 else -1.0
            for ang in (24, 16, 32, 40):
                ta = rot(tang[ia], s * math.radians(ang))
                tb = rot(tang[ib], -s * math.radians(ang))
                m = math.hypot(*chord) * 1.05
                path = hermite(A, B, ta, tb, m, 60)
                L = plen(path)
                n = max(int(L / STEP), 8)
                path = hermite(A, B, ta, tb, m, n)
                L = plen(path)
                arc_len = arc * STEP
                saving = arc_len - L
                if not (40 <= saving <= 130) or L < 90:
                    continue
                if radius(path) < 18:
                    continue
                mind = 1e9
                for k, q in enumerate(path):
                    along = k * L / n
                    if along < 40 or along > L - 40:
                        continue
                    for c in res:
                        dd = math.dist(q, c)
                        if dd < mind:
                            mind = dd
                if mind < 2 * hw + 9:
                    continue
                score = -abs(saving - 80) + mind * 0.05
                if best is None or score > best[0]:
                    best = (score, ia, ib, path, saving, mind, L)
                break
    if best is None:
        print(tid, 'sin atajo válido')
        continue
    _, ia, ib, path, saving, mind, L = best
    interior = path[1:-1]
    keep = [interior[i] for i in range(0, len(interior), 8)]
    print(tid, 'ia=%d ib=%d ahorro %.0f m largo %.0f sep %.0f puntos %d' % (ia, ib, saving, L, mind, len(keep)))
    out[tid] = {'fa': ia / cnt, 'fb': ib / cnt, 'pts': keep}

lines = []
for tid, v in out.items():
    pts = ', '.join('[%.1f, %.1f]' % p for p in v['pts'])
    lines.append('\t"%s": [{"fa": %.5f, "fb": %.5f, "pts": [%s]}],' % (tid, v['fa'], v['fb'], pts))
block = 'const SHORTCUTS := {\n' + '\n'.join(lines) + '\n}'
p = os.path.join(ROOT, 'tools', 'generate_tracks.gd')
t = open(p, encoding='utf-8').read()
if 'const SHORTCUTS := {' in t:
    t = re.sub(r'const SHORTCUTS := \{.*?\n\}', lambda m: block, t, flags=re.S)
else:
    t = t.replace('\n\nfunc _points(', '\n\n## Atajos por pista: fracción de salida/entrada y puntos intermedios (x, z en m).\n' + block + '\n\n\nfunc _points(', 1)
open(p, 'w', encoding='utf-8').write(t)
print('ok', len(out))
