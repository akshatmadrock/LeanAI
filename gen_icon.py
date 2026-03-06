#!/usr/bin/env python3
"""
LeanAI App Icon Generator v7 — Fire + Aura
Clean, modern fire icon: dark navy bg, layered flame shape, soft glow aura.
"""

from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import os, json

SIZE = 1024
CX   = SIZE // 2
CY   = SIZE // 2


# ── 1. Background ─────────────────────────────────────────────────────────────
def make_bg():
    arr = np.zeros((SIZE, SIZE, 3), dtype=np.uint8)
    # Very dark navy base
    arr[:, :] = [10, 10, 22]
    yg, xg = np.mgrid[0:SIZE, 0:SIZE]
    # Subtle warm pool at flame base to give depth
    d1 = np.sqrt((xg - CX)**2 + (yg - int(SIZE * 0.82))**2) / (SIZE * 0.55)
    t1 = np.clip(1 - d1, 0, 1) ** 2.5
    arr[:,:,0] = np.clip(arr[:,:,0] + 80 * t1, 0, 255).astype(np.uint8)
    arr[:,:,1] = np.clip(arr[:,:,1] + 14 * t1, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, 'RGB').convert('RGBA')


# ── 2. Outer aura glow ────────────────────────────────────────────────────────
def make_aura():
    g = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    # Aura centered slightly above image center (flame body center)
    ax, ay = CX, int(SIZE * 0.56)
    layers = [
        (340, 480, 16, (255, 90, 10)),
        (270, 390, 28, (255, 110, 10)),
        (200, 300, 45, (255, 140, 20)),
        (140, 210, 65, (255, 170, 30)),
        ( 90, 140, 85, (255, 200, 60)),
        ( 50,  80, 55, (255, 230, 100)),
    ]
    for hw, hh, alpha, color in layers:
        d.ellipse([ax - hw, ay - hh, ax + hw, ay + hh],
                  fill=(*color, alpha))
    return g.filter(ImageFilter.GaussianBlur(52))


# ── 3. Flame shape (multi-layer teardrop) ─────────────────────────────────────
def flame_teardrop(draw, cx, base_y, width, height, color, blur_r=0):
    """Draw a single flame teardrop: wide at base, narrows to a point at top."""
    tip_y = base_y - height
    # Use a polygon to approximate a teardrop / flame shape
    # Points: wide base, curving sides, narrow tip
    hw = width // 2
    # Control points for a nice flame silhouette
    pts = [
        (cx - hw,           base_y),               # base left
        (cx - int(hw*0.92), base_y - int(height*0.08)),
        (cx - int(hw*0.82), base_y - int(height*0.18)),
        (cx - int(hw*0.72), base_y - int(height*0.28)),
        (cx - int(hw*0.58), base_y - int(height*0.40)),
        (cx - int(hw*0.42), base_y - int(height*0.54)),
        (cx - int(hw*0.24), base_y - int(height*0.68)),
        (cx - int(hw*0.10), base_y - int(height*0.82)),
        (cx,                tip_y),                # tip
        (cx + int(hw*0.10), base_y - int(height*0.82)),
        (cx + int(hw*0.24), base_y - int(height*0.68)),
        (cx + int(hw*0.42), base_y - int(height*0.54)),
        (cx + int(hw*0.58), base_y - int(height*0.40)),
        (cx + int(hw*0.72), base_y - int(height*0.28)),
        (cx + int(hw*0.82), base_y - int(height*0.18)),
        (cx + int(hw*0.92), base_y - int(height*0.08)),
        (cx + hw,           base_y),               # base right
    ]
    draw.polygon(pts, fill=color)


def make_flame():
    g = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)

    base_y = int(SIZE * 0.86)  # flame base y position

    # Outermost flame — deep red/orange, widest
    flame_teardrop(d, CX,       base_y, 440, 680, (200,  35,   5, 230))
    # Side wisps — give asymmetric organic look
    flame_teardrop(d, CX - 90,  base_y, 220, 480, (210,  48,   8, 190))
    flame_teardrop(d, CX + 110, base_y, 190, 440, (215,  52,  10, 185))

    # Mid-layer — orange
    flame_teardrop(d, CX,       base_y, 340, 600, (240,  80,  12, 220))
    flame_teardrop(d, CX - 40,  base_y, 180, 420, (245,  95,  15, 180))
    flame_teardrop(d, CX + 55,  base_y, 160, 400, (248, 100,  18, 175))

    # Inner flame — bright orange-yellow
    flame_teardrop(d, CX,       base_y, 240, 530, (255, 140,  20, 230))

    # Core flame — yellow
    flame_teardrop(d, CX,       base_y, 155, 460, (255, 200,  40, 240))
    flame_teardrop(d, CX + 14,  base_y, 100, 390, (255, 226,  80, 235))

    # Inner core — white-yellow, the hottest part
    flame_teardrop(d, CX + 8,   base_y,  60, 310, (255, 248, 160, 245))
    flame_teardrop(d, CX + 4,   base_y,  30, 220, (255, 255, 230, 250))

    # Apply slight blur to blend layers smoothly
    return g.filter(ImageFilter.GaussianBlur(6))


# ── 4. Inner bright core highlight ────────────────────────────────────────────
def make_core_glow():
    """Extra bright elliptical glow at the base of the flame for realism."""
    g = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    cx = CX + 8
    cy = int(SIZE * 0.72)
    for hw, hh, alpha in [(80, 55, 200), (55, 38, 180), (30, 22, 160), (14, 10, 140)]:
        d.ellipse([cx - hw, cy - hh, cx + hw, cy + hh],
                  fill=(255, 255, 220, alpha))
    return g.filter(ImageFilter.GaussianBlur(18))


# ── 5. Vignette ───────────────────────────────────────────────────────────────
def apply_vignette(img):
    arr = np.array(img).astype(float)
    yg, xg = np.mgrid[0:SIZE, 0:SIZE]
    dv = np.sqrt(((xg - CX) / CX)**2 + ((yg - CY) / CY)**2)
    v  = np.clip(1.08 - dv * 0.14, 0.80, 1.0)[:, :, np.newaxis]
    arr[:, :, :3] *= v
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    out = '/Users/akshatgupta/Documents/NewApp/LeanAI/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(out, exist_ok=True)

    print('Background…');    bg        = make_bg()
    print('Aura…');          aura      = make_aura()
    print('Flame…');         flame     = make_flame()
    print('Core glow…');     core_glow = make_core_glow()

    print('Compositing…')
    canvas = bg
    canvas = Image.alpha_composite(canvas, aura)
    canvas = Image.alpha_composite(canvas, flame)
    canvas = Image.alpha_composite(canvas, core_glow)
    canvas = apply_vignette(canvas)
    master = canvas.convert('RGB')

    sizes = {
        'AppIcon-1024': 1024, 'AppIcon-180': 180, 'AppIcon-120': 120,
        'AppIcon-87': 87,     'AppIcon-80': 80,   'AppIcon-60': 60,
        'AppIcon-58': 58,     'AppIcon-40': 40,   'AppIcon-29': 29,
        'AppIcon-20': 20,
    }
    for name, sz in sizes.items():
        img = master if sz == 1024 else master.resize((sz, sz), Image.LANCZOS)
        img.save(os.path.join(out, f'{name}.png'), 'PNG')
        print(f'  {name}.png')

    mapping = [
        ('AppIcon-20',   'iphone', '1x', '20x20'),
        ('AppIcon-40',   'iphone', '2x', '20x20'),
        ('AppIcon-60',   'iphone', '3x', '20x20'),
        ('AppIcon-29',   'iphone', '1x', '29x29'),
        ('AppIcon-58',   'iphone', '2x', '29x29'),
        ('AppIcon-87',   'iphone', '3x', '29x29'),
        ('AppIcon-80',   'iphone', '2x', '40x40'),
        ('AppIcon-120',  'iphone', '3x', '40x40'),
        ('AppIcon-120',  'iphone', '2x', '60x60'),
        ('AppIcon-180',  'iphone', '3x', '60x60'),
        ('AppIcon-1024', 'ios-marketing', '1x', '1024x1024'),
    ]
    seen = set(); images = []
    for name, idiom, scale, sz in mapping:
        k = f'{name}_{idiom}_{scale}_{sz}'
        if k in seen: continue
        seen.add(k)
        images.append({'filename': f'{name}.png', 'idiom': idiom,
                       'scale': scale, 'size': sz})
    with open(os.path.join(out, 'Contents.json'), 'w') as f:
        json.dump({'images': images, 'info': {'author': 'xcode', 'version': 1}},
                  f, indent=2)
    print(f'\nDone → {out}')

if __name__ == '__main__':
    main()
