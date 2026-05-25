"""Generate the Worship Hub launcher icon (1024x1024 PNG).

Run: python tool/make_icon.py
Output: assets/icon/icon.png (and icon_foreground.png for adaptive icon)
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def diagonal_gradient(size, stops):
    """Paint a diagonal gradient with N colour stops (top-left -> bottom-right)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    n = len(stops) - 1
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))  # 0..1 along the diagonal
            seg = min(int(t * n), n - 1)
            local = t * n - seg
            px[x, y] = lerp(stops[seg], stops[seg + 1], local)
    return img


def find_font():
    candidates = [
        # Windows system fonts that include U+266A (♪) and U+1D160 (𝅘𝅥𝅮)
        r"C:\Windows\Fonts\seguisym.ttf",  # Segoe UI Symbol
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            return p
    return None


def draw_glyph(img, glyph, fill, size_ratio=0.62):
    draw = ImageDraw.Draw(img)
    font_path = find_font()
    if not font_path:
        return img
    # Binary-search the font size that fits the glyph in size_ratio of the canvas.
    target = int(SIZE * size_ratio)
    lo, hi = 100, 1400
    best = None
    while lo <= hi:
        mid = (lo + hi) // 2
        font = ImageFont.truetype(font_path, mid)
        bbox = draw.textbbox((0, 0), glyph, font=font)
        h = bbox[3] - bbox[1]
        w = bbox[2] - bbox[0]
        if max(w, h) > target:
            hi = mid - 1
        else:
            best = (font, bbox)
            lo = mid + 1
    if not best:
        return img
    font, bbox = best
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (SIZE - w) // 2 - bbox[0]
    y = (SIZE - h) // 2 - bbox[1]
    # Soft shadow for depth
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.text((x + 8, y + 14), glyph, fill=(0, 0, 0, 110), font=font)
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    img.alpha_composite(shadow)
    draw = ImageDraw.Draw(img)
    draw.text((x, y), glyph, fill=fill, font=font)
    return img


def make_icon():
    # Aurora-ish diagonal gradient: cyan -> violet -> magenta
    bg = diagonal_gradient(
        SIZE,
        [(0, 232, 255), (139, 92, 246), (255, 58, 163)],
    ).convert("RGBA")

    # Add a subtle inner glow for depth
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    margin = int(SIZE * 0.08)
    gdraw.rounded_rectangle(
        (margin, margin, SIZE - margin, SIZE - margin),
        radius=int(SIZE * 0.18),
        outline=(255, 255, 255, 60),
        width=6,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(8))
    bg.alpha_composite(glow)

    # Beamed eighth notes glyph — universally recognisable as "music"
    icon = draw_glyph(bg.copy(), "♫", fill=(255, 255, 255, 240), size_ratio=0.58)

    icon_path = OUT_DIR / "icon.png"
    icon.save(icon_path, "PNG")

    # Adaptive-icon foreground: same glyph, transparent background, with
    # extra padding (Android masks ~33% inset).
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_glyph(fg, "♫", fill=(255, 255, 255, 255), size_ratio=0.42)
    fg_path = OUT_DIR / "icon_foreground.png"
    fg.save(fg_path, "PNG")

    return icon_path, fg_path


if __name__ == "__main__":
    icon_path, fg_path = make_icon()
    print(f"Wrote {icon_path}")
    print(f"Wrote {fg_path}")
