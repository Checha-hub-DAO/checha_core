# build_c02_symbol_pack.py — FAST (Pillow+NumPy, без Inkscape/Cairo)
# Генерує: C02_symbol_pack_v1.0
# - posters 1200×1200 (radial/wave, light/dark)
# - badges 128×128
# - анімації GIF (glow 4s @24fps, vibe 3s @24fps)
# MP4 навмисне вимкнено для швидкості/стабільності.

import math, zipfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps, ImageDraw
import imageio.v2 as imageio

ROOT = Path(__file__).parent
OUT  = ROOT / "C02_symbol_pack_v1.0"
OUT.mkdir(exist_ok=True)

# ---- Константи ----
W = H = 1200
BADGE = (128, 128)
FPS = 24
GLOW_SECONDS = 4
VIBE_SECONDS = 3
DO_ANIMATIONS = True   # постав False, якщо треба ультрашвидко (лише PNG)

# ---- Утиліти ----
def hex2rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def make_linear_gradient(top, bot, w=W, h=H):
    tcol = np.array(hex2rgb(top), dtype=np.float32)[None, None, :]   # (1,1,3)
    bcol = np.array(hex2rgb(bot), dtype=np.float32)[None, None, :]   # (1,1,3)
    ys   = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]     # (h,1,1)
    col_line = tcol + (bcol - tcol) * ys                              # (h,1,3)
    img = np.repeat(col_line, w, axis=1).astype(np.uint8)             # (h,w,3)
    return Image.fromarray(img)

def make_radial_gradient(c1, c2, c3, w=W, h=H, cx=None, cy=None, r=None):
    c1 = np.array(hex2rgb(c1), dtype=np.float32)
    c2 = np.array(hex2rgb(c2), dtype=np.float32)
    c3 = np.array(hex2rgb(c3), dtype=np.float32)
    if cx is None: cx = w/2
    if cy is None: cy = h*0.4
    if r is None:  r = max(w, h)*0.7
    yy, xx = np.ogrid[:h, :w]
    d = np.sqrt((xx - cx)**2 + (yy - cy)**2) / r
    d = np.clip(d, 0, 1)
    mid = 0.55
    t_mid = np.clip(d/mid, 0, 1)[..., None]      # (h,w,1)
    t_out = np.clip((d-mid)/(1-mid), 0, 1)[..., None]
    part1 = c1 + (c2 - c1) * t_mid               # (h,w,3)
    part2 = c2 + (c3 - c2) * t_out               # (h,w,3)
    mask  = (d <= mid)[..., None]
    img = np.where(mask, part1, part2).astype(np.uint8)
    return Image.fromarray(img)

def save_png(img: Image.Image, path: Path): img.save(path, "PNG")

def mp4_from_frames(frames, out_path: Path, fps=FPS):
    # навмисно вимкнено для стабільності збірки
    print(f"[skip] mp4 export disabled: {out_path.name}")

def gif_from_frames(frames, out_path: Path, fps=FPS):
    imageio.mimsave(out_path, frames, fps=fps, loop=0)

# ---- Радіальний символ (кільця) ----
def render_radial(light=True, glow_scale=1.0):
    if light:
        bg = make_radial_gradient("#a78bfa", "#7c3aed", "#4c1d95")
        ring1 = "#f9e79f"; ring2 = "#fde68a"
    else:
        bg = make_radial_gradient("#1f2937", "#0b1220", "#00040a")
        ring1 = "#f5f3c4"; ring2 = "#e6e1a5"
    img = bg.convert("RGBA")
    draw = ImageDraw.Draw(img)
    base = [140, 200, 260, 320, 380, 440, 500]
    cx = cy = W//2
    for i, rv in enumerate(base):
        rr = int(rv * (0.6 + 0.4 * glow_scale))
        bbox = [cx-rr, cy-rr, cx+rr, cy+rr]
        if i % 2 == 0:
            draw.ellipse(bbox, outline=ring1, width=6)
        else:
            draw.ellipse(bbox, outline=ring2, width=3)
    return img

# ---- Хвилі (voice line) ----
def wave_points(y0, a, ph, k=2*math.pi/300.0):
    pts = []
    for x in range(0, W+1, 12):
        y = y0 + a * math.sin(k*x + ph)
        pts.append((x, y))
    return pts

def render_wave(light=True, amp=1.0, phase=0.0):
    if light:
        bg = make_linear_gradient("#c4b5fd", "#7c3aed")
        w1, w2 = "#fff7cc", "#fde68a"
    else:
        bg = make_linear_gradient("#111827", "#0b1220")
        w1, w2 = "#f1e6a8", "#dfd691"
    img = bg.convert("RGBA")
    draw = ImageDraw.Draw(img)
    A1 = 80*amp; A2 = 80*amp*0.75; A3 = 80*amp
    for (y0, a, ph, width, col) in [
        (600, A1, phase,     10, w1),
        (680, A2, phase+0.7,  6, w2),
        (520, A3, phase-0.7,  6, w2),
    ]:
        draw.line(wave_points(y0, a, ph), fill=col, width=width)
    return img

# ---- Статика ----
def make_static():
    items = [
        ("C02_radial_poster_light.png", render_radial(True, 1.0)),
        ("C02_radial_poster_dark.png",  render_radial(False, 1.0)),
        ("C02_wave_poster_light.png",   render_wave(True, 1.0, 0.0)),
        ("C02_wave_poster_dark.png",    render_wave(False, 1.0, 0.0)),
    ]
    for name, img in items:
        save_png(img, OUT/name)
    # badges
    for base in ["C02_radial_poster_light.png","C02_radial_poster_dark.png",
                 "C02_wave_poster_light.png","C02_wave_poster_dark.png"]:
        img = Image.open(OUT/base).convert("RGBA")
        thumb = ImageOps.fit(img, BADGE, Image.LANCZOS)
        save_png(thumb, OUT/base.replace("poster", "badge"))

# ---- Анімації ----
def make_radial_glow(light=True, fps=FPS):
    frames=[]; total = GLOW_SECONDS*fps
    for i in range(total):
        t = i/total
        glow = 0.8 + 0.2*(0.5*(1-math.cos(2*math.pi*t)))
        frames.append(render_radial(light, glow))
    prefix=f"C02_radial_anim_{'light' if light else 'dark'}"
    gif_from_frames(frames, OUT/(prefix+".gif"), fps=fps)
    mp4_from_frames(frames, OUT/(prefix+".mp4"), fps=fps)

def make_radial_vibe(light=True, fps=FPS):
    frames=[]; total = VIBE_SECONDS*fps
    for i in range(total):
        t = i/total
        glow = 0.96 + 0.04*math.sin(2*math.pi*1.5*t)
        frames.append(render_radial(light, glow))
    prefix=f"C02_radial_vibe_{'light' if light else 'dark'}"
    gif_from_frames(frames, OUT/(prefix+".gif"), fps=fps)
    mp4_from_frames(frames, OUT/(prefix+".mp4"), fps=fps)

def make_wave_glow(light=True, fps=FPS):
    frames=[]; total = GLOW_SECONDS*fps
    for i in range(total):
        t = i/total
        phase = 2*math.pi*t
        amp   = 1.0 + 0.08*(0.5*(1-math.cos(2*math.pi*t)))
        frames.append(render_wave(light, amp, phase))
    prefix=f"C02_wave_anim_{'light' if light else 'dark'}"
    gif_from_frames(frames, OUT/(prefix+".gif"), fps=fps)
    mp4_from_frames(frames, OUT/(prefix+".mp4"), fps=fps)

def make_wave_vibe(light=True, fps=FPS):
    frames=[]; total = VIBE_SECONDS*fps
    for i in range(total):
        t = i/total
        phase = 6*math.pi*t
        amp   = 1.0 + 0.08*math.sin(2*math.pi*1.5*t)
        frames.append(render_wave(light, amp, phase))
    prefix=f"C02_wave_vibe_{'light' if light else 'dark'}"
    gif_from_frames(frames, OUT/(prefix+".gif"), fps=fps)
    mp4_from_frames(frames, OUT/(prefix+".mp4"), fps=fps)

README = """# C02 — GLOSSARY (Мова / Терміни) · Symbol Pack v1.0
Вміст:
- Radial Waves: badge (128), poster (1200), anim (glow 4s, vibe 3s) у light/dark.
- Voice Line: badge (128), poster (1200), anim (glow 4s, vibe 3s) у light/dark.
Анімації GIF @24fps. _Stamp:_ C02_symbol_pack v1.0 · С.Ч.
"""

def build_all():
    make_static()
    if DO_ANIMATIONS:
        make_radial_glow(True);  make_radial_glow(False)
        make_radial_vibe(True);  make_radial_vibe(False)
        make_wave_glow(True);    make_wave_glow(False)
        make_wave_vibe(True);    make_wave_vibe(False)
    (OUT/"README.md").write_text(README, encoding="utf-8")
    zip_path = ROOT/"C02_symbol_pack_v1.0.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for p in OUT.rglob("*"):
            z.write(p, arcname=p.relative_to(OUT.parent))
    print("✅ Done:", zip_path)

if __name__ == "__main__":
    build_all()

# touch: trigger pre-release
