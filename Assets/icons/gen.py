#!/usr/bin/env python3
"""Regenerates every icon asset: python3 gen.py  (needs rsvg-convert + iconutil)."""
import os, subprocess, math
D = os.path.dirname(os.path.abspath(__file__))
K = 'fill="#000"'
S = 'stroke="#000" stroke-linecap="round" stroke-linejoin="round" fill="none"'

def dots(pts, r, extra=""):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" {extra}/>' for x, y in pts)

# --- template glyphs on 18x18 canvas: (shown, hidden) -----------------------
GLYPHS = {
 "fold-chevron": (
  dots([(3,9),(6.4,9)],1.7,K) + f'<path d="M9.6 4v10" {S} stroke-width="1.5"/><path d="M15.8 6.2L13.2 9l2.6 2.8" {S} stroke-width="1.6"/>',
  dots([(3,9),(6.4,9)],1.7,K+' opacity=".35"') + f'<path d="M9.6 4v10" {S} stroke-width="1.5"/><path d="M13.2 6.2L15.8 9l-2.6 2.8" {S} stroke-width="1.6"/>'),
 "peek-strip": (
  '<defs><mask id="m"><rect width="18" height="18" fill="#fff"/>' + dots([(6.5,12.5),(9,12.5),(11.5,12.5)],1,'fill="#000"') + '</mask></defs>'
  f'<rect x="1.5" y="2" width="15" height="4" rx="1.6" {K}/><rect x="3" y="9.5" width="12" height="6" rx="2" {K} mask="url(#m)"/>',
  f'<rect x="1.5" y="2" width="15" height="4" rx="1.6" {K}/><rect x="3.5" y="10" width="11" height="5.2" rx="1.8" {S} stroke-width="1.1" stroke-dasharray="1.6 1.5"/>'),
 "curtain-panel": (
  f'<rect x="1.5" y="3.5" width="15" height="11" rx="3" {S} stroke-width="1.5"/>' + dots([(4.6,9),(7.6,9)],1.1,K) + f'<path d="M11.5 6.5v5" {S} stroke-width="1.5"/>',
  f'<rect x="1.5" y="3.5" width="15" height="11" rx="3" {S} stroke-width="1.5"/><rect x="3.8" y="5.8" width="6.4" height="6.4" rx="1.4" {K}/><path d="M11.5 6.5v5" {S} stroke-width="1.5"/>'),
}
# concept -> (gradient top, bottom)
COLORS = {"fold-chevron":("#6C7BFF","#2B2F9E"), "peek-strip":("#35D0C0","#0A6B7A"), "curtain-panel":("#FFB05A","#E2475B")}

def squircle(a=412, c=512, n=5, steps=360):
    pts = []
    for i in range(steps):
        t = 2*math.pi*i/steps
        s, co = math.sin(t), math.cos(t)
        x = c + a*math.copysign(abs(co)**(2/n), co); y = c + a*math.copysign(abs(s)**(2/n), s)
        pts.append(f"{x:.1f},{y:.1f}")
    return "M" + " L".join(pts) + "Z"

def app_svg(name):
    g0, g1 = COLORS[name]
    glyph = GLYPHS[name][0].replace("#000", "#fff").replace('id="m"', 'id="mk"').replace("url(#m)", "url(#mk)")
    # mask knockouts must stay black: restore inside mask
    glyph = glyph.replace('<circle', '<circle') 
    if "mask" in glyph:
        glyph = glyph.replace('<rect width="18" height="18" fill="#fff"/>', '<rect width="18" height="18" fill="#fff"/>')
        glyph = glyph.replace('fill="#fff"/><circle', 'fill="#fff"/><circle')
        # knockout circles were turned white; make them black again
        a, b = glyph.split("</mask>")
        a = a.replace('<circle', '<circle').replace('fill="#fff"/>', 'fill="#fff"/>')
        import re
        head, rest = a.split('<rect width="18" height="18" fill="#fff"/>')
        rest = rest.replace('fill="#fff"', 'fill="#000"')
        glyph = head + '<rect width="18" height="18" fill="#fff"/>' + rest + "</mask>" + b
    p = squircle()
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{g0}"/><stop offset="1" stop-color="{g1}"/></linearGradient>
<linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".28"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient>
<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000" flood-opacity=".35"/></filter>
<filter id="gs" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#000" flood-opacity=".3"/></filter>
<clipPath id="sq"><path d="{p}"/></clipPath>
</defs>
<path d="{p}" fill="#000" filter="url(#sh)"/>
<path d="{p}" fill="url(#bg)"/>
<g clip-path="url(#sq)"><rect width="1024" height="560" fill="url(#hl)"/></g>
<path d="{p}" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="3"/>
<g transform="translate(212 212) scale(33.5)" filter="url(#gs)">{glyph}</g>
</svg>'''

def tpl_svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">{body}</svg>'

def run(*a): subprocess.run(a, check=True)

for name, (shown, hidden) in GLYPHS.items():
    d = os.path.join(D, name); os.makedirs(d, exist_ok=True)
    for st, body in (("shown", shown), ("hidden", hidden)):
        base = os.path.join(d, f"menubar-{st}")
        open(base + ".svg", "w").write(tpl_svg(body))
        run("rsvg-convert", "-w", "18", "-h", "18", "-o", base + ".png", base + ".svg")
        run("rsvg-convert", "-w", "36", "-h", "36", "-o", base + "@2x.png", base + ".svg")
        run("rsvg-convert", "-f", "pdf", "-o", base + ".pdf", base + ".svg")
    src = os.path.join(d, "AppIcon.svg"); open(src, "w").write(app_svg(name))
    run("rsvg-convert", "-w", "1024", "-h", "1024", "-o", os.path.join(d, "AppIcon-1024.png"), src)
    iset = os.path.join(d, "AppIcon.iconset"); os.makedirs(iset, exist_ok=True)
    for sz in (16, 32, 128, 256, 512):
        for sc in (1, 2):
            px = sz*sc; suf = "@2x" if sc == 2 else ""
            run("rsvg-convert", "-w", str(px), "-h", str(px), "-o", os.path.join(iset, f"icon_{sz}x{sz}{suf}.png"), src)
    run("iconutil", "-c", "icns", iset, "-o", os.path.join(d, "AppIcon.icns"))
print("ok")
