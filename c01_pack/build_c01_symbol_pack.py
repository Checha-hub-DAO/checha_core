# build_c01_symbol_pack.py
# Генерує C01_symbol_extended_pack v1.1 (badges, posters, GIF/MP4 @30fps, 6s) + ZIP
# Рендер SVG->PNG: спершу пробує Inkscape CLI, фолбек — CairoSVG (якщо є libcairo)
import io, math, zipfile, tempfile, subprocess, os
from pathlib import Path
from PIL import Image, ImageOps
import imageio.v2 as imageio

ROOT = Path(__file__).parent
OUT  = ROOT / "C01_symbol_extended_pack_v1.1"
OUT.mkdir(exist_ok=True)

def svg_to_png(svg_text: str, w: int, h: int) -> Image.Image:
    """Пробує Inkscape; якщо не вийде — CairoSVG (потребує libcairo)."""
    from PIL import Image as _Img
    # 1) Inkscape
    inkscape_bins = [
        os.environ.get("INKSCAPE_BIN"),
        r"C:\Program Files\Inkscape\bin\inkscape.com",
        r"C:\Program Files\Inkscape\bin\inkscape.exe",
        "inkscape",
    ]
    for ib in inkscape_bins:
        if not ib:
            continue
        try:
            with tempfile.TemporaryDirectory() as td:
                svg_p = Path(td) / "in.svg"
                out_p = Path(td) / "out.png"
                svg_p.write_text(svg_text, encoding="utf-8")
                cmd = [ib, str(svg_p), "--export-type=png", f"--export-filename={out_p}",
                       f"--export-width={w}", f"--export-height={h}"]
                subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                return _Img.open(out_p).convert("RGBA")
        except Exception:
            pass
    # 2) Фолбек — CairoSVG (може впасти без libcairo на Windows)
    try:
        import cairosvg
        png = cairosvg.svg2png(bytestring=svg_text.encode("utf-8"),
                               output_width=w, output_height=h)
        return _Img.open(io.BytesIO(png)).convert("RGBA")
    except Exception as e:
        raise RuntimeError(
            "Немає рендерера SVG: або вкажи INKSCAPE_BIN, або встанови libcairo для CairoSVG."
        ) from e

def save_png(img: Image.Image, path: Path): img.save(path, "PNG")

def mp4_from_frames(frames, out_path: Path, fps=30):
    """Лояльний енкодер MP4: якщо впаде — просто попереджаємо."""
    try:
        imageio.mimsave(out_path, frames, fps=fps, quality=9)
    except Exception as e:
        print(f"[warn] mp4 encode failed: {e}")

def gif_from_frames(frames, out_path: Path, fps=30):
    imageio.mimsave(out_path, frames, fps=fps, loop=0)

def dna_svg(light=True, turns=3, amp=1.0):
    if light:
        bg_top, bg_mid, bg_bot = "#60a5fa", "#0ea5e9", "#2563eb"
        lbl = "#ffffff"; s1="#ffffff"; s2="#e5eefc"; rung="#ffffff"
    else:
        bg_top, bg_mid, bg_bot = "#0b1220", "#0b1327", "#0a1020"
        lbl = "#e5e7eb"; s1="#9bd4ff"; s2="#60a5fa"; rung="#bfe3ff"
    size = 1200; cx=cy=600; r=420
    top = cy - r*0.68; bot = cy + r*0.68; h = bot-top
    samples=260; gap=0.15*r; A=0.45*r*amp
    p1=[]; p2=[]; rungs=[]
    for i in range(samples+1):
        t=i/samples; y=top+t*h; phase=2*math.pi*turns*t
        xoff=A*math.sin(phase); x1=cx-xoff-gap; x2=cx+xoff+gap
        p1.append((x1,y)); p2.append((x2,y))
        if i % max(10, samples//40)==0 and 0<i<samples:
            tilt=0.05*r*math.cos(phase); rungs.append((x1,y-tilt,x2,y+tilt))
    def to_path(points):
        seg=[]
        for j,(x,y) in enumerate(points):
            seg.append(("M" if j==0 else "L")+f"{x:.1f},{y:.1f}")
        return " ".join(seg)
    d1=to_path(p1); d2=to_path(p2)
    rung_svg="\n".join([f'<line x1="{a:.1f}" y1="{b:.1f}" x2="{c:.1f}" y2="{d:.1f}" stroke="{rung}" stroke-width="10" stroke-linecap="round"/>' for (a,b,c,d) in rungs])
    return f"""<svg xmlns='http://www.w3.org/2000/svg' width='1200' height='1200' viewBox='0 0 1200 1200'>
  <defs>
    <radialGradient id='bg' cx='50%' cy='40%' r='70%'>
      <stop offset='0%' stop-color='{bg_top}'/><stop offset='55%' stop-color='{bg_mid}'/><stop offset='100%' stop-color='{bg_bot}'/>
    </radialGradient>
    <style>.lbl{{font:700 64px ui-monospace,Menlo,Consolas,monospace; text-anchor:middle; fill:{lbl};}}</style>
  </defs>
  <rect width='1200' height='1200' fill='url(#bg)'/>
  <g>
    <circle cx='{cx}' cy='{cy}' r='{r}' fill='none' stroke='{lbl}22' stroke-width='4'/>
    <path d='{d1}' fill='none' stroke='{s1}' stroke-width='16' stroke-linecap='round'/>
    <path d='{d2}' fill='none' stroke='{s2}' stroke-width='16' stroke-linecap='round'/>
    {rung_svg}
  </g>
  <text class='lbl' x='600' y='1120'>C01</text>
</svg>"""

def make_static():
    posters=[("C01_poster_light.png", dna_svg(True,3,1.0)),
             ("C01_poster_dark.png",  dna_svg(False,3,1.0))]
    for name, svg in posters:
        save_png(svg_to_png(svg,1200,1200), OUT/name)
    for base in ["C01_poster_light.png","C01_poster_dark.png"]:
        img=Image.open(OUT/base).convert("RGBA")
        save_png(ImageOps.fit(img,(128,128),Image.LANCZOS), OUT/base.replace("poster","badge"))

def make_glow(light=True, seconds=6, fps=30):
    frames=[]; total=seconds*fps
    for i in range(total):
        t=i/total
        amp=1.0 + 0.08*(0.5*(1-math.cos(2*math.pi*t)))
        svg=dna_svg(light=light, turns=3, amp=amp)
        frames.append(svg_to_png(svg,1200,1200))
    prefix=f"C01_poster_{'light' if light else 'dark'}_anim"
    gif_from_frames(frames, OUT/(prefix+".gif"), fps=fps)
    mp4_from_frames(frames, OUT/(prefix+".mp4"), fps=fps)

README = """# C01 — PARAMETERS · Symbol Extended Pack v1.1
Вміст: badges (128), posters (1200), animated (meditative glow 6s @30fps).
_Stamp:_ C01_symbol_extended_pack v1.1 · С.Ч.
"""

def build_all():
    make_static()
    make_glow(True,6,30); make_glow(False,6,30)
    (OUT/"README.md").write_text(README, encoding="utf-8")
    zip_path = ROOT/"C01_symbol_extended_pack_v1.1.zip"
    with zipfile.ZipFile(zip_path,"w",zipfile.ZIP_DEFLATED) as z:
        for p in OUT.rglob("*"):
            z.write(p, arcname=p.relative_to(OUT.parent))
    print("✅ Done:", zip_path)

if __name__=="__main__":
    build_all()
