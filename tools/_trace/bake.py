"""Convierte los trazados de tracks_px.py (px de las tarjetas) a metros y escribe LAYOUT_* y FEATURES en tools/generate_tracks.gd.
   python tools/_trace/bake.py
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.environ['TEMP'])
from tracks_px import T
from lay import resample

LEN = {1: 1920, 2: 2100, 3: 1950, 4: 2200, 5: 2050, 6: 2150, 7: 2000, 8: 2100, 9: 2250, 10: 2300}
NAMES = {1: 'COSTA', 2: 'NEON', 3: 'BOSQUE', 4: 'CIRCUITO', 5: 'VOLCAN', 6: 'DESIERTO', 7: 'INDUSTRIAL', 8: 'NIEVE', 9: 'EXTREMO', 10: 'FANTASIA'}
IDS = {1: '01_costa', 2: '02_neon', 3: '03_bosque', 4: '04_circuito', 5: '05_volcan', 6: '06_desierto', 7: '07_industrial', 8: '08_nieve', 9: '09_extremo', 10: '10_fantasia'}
SM = {1: (0.4, 2), 8: (0.3, 2)}

# Elementos (px de la tarjeta). turbo: pos, lat; ramp: pos, lat, len; bridge/tunnel: a -> b (en el sentido de la carrera), hazard.
F = {
 1: [('bridge', (264, 238), (264, 188), 'water'), ('turbo', (150, 316), 0.0), ('turbo', (264, 150), 0.0), ('turbo', (100, 212), 0.0), ('turbo', (205, 100), 0.0)],
 2: [('tunnel', (110, 350), (190, 337), ''), ('tunnel', (190, 104), (100, 105), ''), ('ramp', (35, 300), 0.0, 9), ('ramp', (205, 238), 0.0, 9),
     ('turbo', (240, 318), 0.0), ('turbo', (172, 180), 0.0), ('turbo', (42, 190), 0.0)],
 3: [('bridge', (66, 196), (102, 236), 'water'), ('bridge', (209, 282), (214, 226), 'water'), ('turbo', (135, 350), 0.0), ('turbo', (150, 158), 0.0),
     ('turbo', (62, 104), 0.0)],
 4: [('turbo', (150, 324), 0.0), ('turbo', (150, 109), 0.0), ('turbo', (200, 170), 0.0), ('turbo', (62, 200), 0.0)],
 5: [('bridge', (150, 128), (104, 110), 'lava'), ('ramp', (100, 338), 0.0, 9), ('turbo', (200, 332), 0.0), ('turbo', (230, 158), 0.0), ('turbo', (42, 235), 0.0)],
 6: [('ramp', (195, 80), 0.0, 9), ('turbo', (98, 145), 0.0), ('turbo', (235, 72), 0.0), ('turbo', (140, 272), 0.0), ('turbo', (270, 245), 0.0)],
 7: [('ramp', (72, 170), 0.0, 9), ('ramp', (205, 213), 0.0, 9), ('turbo', (125, 291), 0.0), ('turbo', (150, 125), 0.0), ('turbo', (256, 180), 0.0)],
 8: [('tunnel', (155, 94), (100, 98), ''), ('bridge', (231, 220), (208, 188), 'water'), ('ramp', (115, 303), 0.0, 9),
     ('turbo', (252, 305), 0.0), ('turbo', (246, 126), 0.0), ('turbo', (46, 128), 0.0)],
 9: [('turbo', (183, 293), 0.0), ('turbo', (233, 68), 0.0), ('turbo', (198, 159), 0.0), ('turbo', (45, 130), 0.0)],
 10: [('bridge', (100, 258), (126, 280), 'void'), ('turbo', (203, 315), 0.0), ('turbo', (173, 68), 0.0), ('turbo', (60, 150), 0.0), ('turbo', (255, 190), 0.0)],
}


def smooth(P, a, times):
    for _ in range(times):
        n = len(P)
        P = [((1 - a) * P[i][0] + a * (P[i - 1][0] + P[(i + 1) % n][0]) / 2, (1 - a) * P[i][1] + a * (P[i - 1][1] + P[(i + 1) % n][1]) / 2) for i in range(n)]
    return P


def fmt(p):
    return '[%.1f, %.1f]' % (p[0], p[1])


lines = {}
feat = []
for k, P in T.items():
    if k in SM:
        P = smooth(P, *SM[k])
    _, tot = resample(P)
    s = LEN[k] / tot
    P2 = [(x * s, y * s) for x, y in P]
    cx = sum(p[0] for p in P2) / len(P2)
    cy = sum(p[1] for p in P2) / len(P2)
    conv = lambda q: ((q[0] * s - cx), (q[1] * s - cy))
    lines[NAMES[k]] = 'const LAYOUT_%s := [%s]' % (NAMES[k], ', '.join(fmt((x - cx, y - cy)) for x, y in P2))
    items = []
    for f in F.get(k, []):
        t = f[0]
        if t == 'turbo':
            items.append('{"type": "turbo", "a": %s, "lat": %.1f}' % (fmt(conv(f[1])), f[2]))
        elif t == 'ramp':
            items.append('{"type": "ramp", "a": %s, "lat": %.1f, "len": %d}' % (fmt(conv(f[1])), f[2], f[3]))
        else:
            items.append('{"type": "%s", "a": %s, "b": %s, "hazard": "%s"}' % (t, fmt(conv(f[1])), fmt(conv(f[2])), f[3]))
    feat.append('\t"%s": [%s],' % (IDS[k], ', '.join(items)))

p = os.path.join(os.path.dirname(__file__), '..', 'generate_tracks.gd')
t = open(p, encoding='utf-8').read()
for n, l in lines.items():
    t, c = re.subn(r'const LAYOUT_%s := \[.*\]' % n, lambda m: l, t)
    assert c == 1, n
block = 'const FEATURES := {\n' + '\n'.join(feat) + '\n}'
if 'const FEATURES := {' in t:
    t = re.sub(r'const FEATURES := \{.*?\n\}', lambda m: block, t, flags=re.S)
else:
    t = t.replace('\n\nfunc _points(', '\n\n## Elementos de cada pista por coordenadas (m); _track() los convierte en fracciones de la vuelta.\n' + block + '\n\n\nfunc _points(', 1)
open(p, 'w', encoding='utf-8').write(t)
print('ok', len(feat))
