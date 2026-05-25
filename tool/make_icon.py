"""Render the Worship Hub launcher icon as the brand-mark logo
(conic-gradient outer ring + dark inner + inner cyan→violet gradient
with soft blur). Matches the brand-mark used on the web login screen.

Run: python tool/make_icon.py
Outputs:
  assets/icon/icon.png            — 1024x1024, full-bleed (dark bg + mark)
  assets/icon/icon_foreground.png — adaptive-icon foreground (transparent
                                    background, generous safe-area padding)
"""

from math import atan2, pi
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Sanctuary OS palette
INK_0 = (4, 6, 14)
INK_1 = (7, 10, 23)
AURORA_CYAN = (0, 232, 255)
AURORA_VIOLET = (139, 92, 246)
AURORA_MAGENTA = (255, 58, 163)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def conic_gradient(size, stops, start_angle_deg=140):
    """Render an N-stop conic gradient inscribed in a `size x size` square.

    `stops` is a list of RGB tuples; the gradient wraps so the last colour
    blends back into the first. `start_angle_deg` is where stop 0 sits,
    measured clockwise from 12 o'clock.
    """
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx = cy = (size - 1) / 2
    start = (start_angle_deg % 360) / 360.0
    n = len(stops)
    for y in range(size):
        for x in range(size):
            # angle in [0, 1) starting from +y (12 o'clock), clockwise
            ang = atan2(x - cx, cy - y)  # -π..π, 0 at 12 o'clock
            t = (ang / (2 * pi) + 1) % 1
            t = (t - start) % 1
            # Find segment between two stops.
            seg_f = t * n
            seg = int(seg_f)
            local = seg_f - seg
            a = stops[seg % n]
            b = stops[(seg + 1) % n]
            px[x, y] = lerp(a, b, local)
    return img


def diagonal_gradient(size, c0, c1):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(c0, c1, t)
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def render_brand_mark(canvas_size, on_transparent=False):
    """Render the brand-mark composition. Returns an RGBA image of size
    `canvas_size x canvas_size`.

    Layers (largest to smallest):
      1. dark backdrop (only if `on_transparent` is False)
      2. conic-gradient rounded square (outer ring)
      3. dark inner rounded square (slightly inset)
      4. linear-gradient inner square (further inset) with a tiny blur
      5. subtle inner highlight
    """
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))

    # Convert web brand-mark proportions (24px outer / 2px ring / 4px center inset)
    # to the icon canvas. The outer mark fills the canvas; the inset numbers
    # below are tuned visually to feel like the web version on a real phone.
    outer_radius = int(canvas_size * 0.235)  # ~240 / 1024
    ring_inset = int(canvas_size * 0.052)    # the dark ring sits ~54px in
    inner_radius = int(canvas_size * 0.155)
    center_inset = int(canvas_size * 0.16)
    center_radius = int(canvas_size * 0.10)

    if not on_transparent:
        # Dark backdrop
        backdrop = Image.new("RGBA", (canvas_size, canvas_size), INK_0 + (255,))
        img.alpha_composite(backdrop)

    # Layer 2 — conic outer
    conic = conic_gradient(
        canvas_size,
        [AURORA_CYAN, AURORA_VIOLET, AURORA_MAGENTA, AURORA_CYAN],
        start_angle_deg=140,
    ).convert("RGBA")
    conic.putalpha(rounded_mask(canvas_size, outer_radius))
    img.alpha_composite(conic)

    # Layer 3 — dark inner rounded rect
    inner_dark = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ImageDraw.Draw(inner_dark).rounded_rectangle(
        (
            ring_inset,
            ring_inset,
            canvas_size - 1 - ring_inset,
            canvas_size - 1 - ring_inset,
        ),
        radius=inner_radius,
        fill=INK_1 + (255,),
    )
    img.alpha_composite(inner_dark)

    # Layer 4 — center linear gradient (cyan → violet at ~135°),
    # masked to a smaller rounded square and lightly blurred.
    center_size = canvas_size - center_inset * 2
    center_grad = diagonal_gradient(center_size, AURORA_CYAN, AURORA_VIOLET).convert(
        "RGBA"
    )
    center_grad.putalpha(rounded_mask(center_size, center_radius))
    # Pad to canvas size + blur the edges slightly.
    padded = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    padded.paste(center_grad, (center_inset, center_inset), center_grad)
    padded = padded.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(padded)

    # Layer 5 — top-left highlight inside the center square for a glassy feel
    highlight = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    hl_draw = ImageDraw.Draw(highlight)
    hl_box = (
        center_inset + int(center_size * 0.08),
        center_inset + int(center_size * 0.08),
        center_inset + int(center_size * 0.55),
        center_inset + int(center_size * 0.45),
    )
    hl_draw.rounded_rectangle(
        hl_box, radius=int(center_radius * 0.7), fill=(255, 255, 255, 38)
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(highlight)

    return img


def make():
    full = render_brand_mark(SIZE, on_transparent=False)
    full.save(OUT_DIR / "icon.png", "PNG")

    # Adaptive-icon foreground: the brand-mark drawn smaller on a transparent
    # canvas so Android's launcher mask (~33% safe inset) doesn't clip it.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    inner_size = int(SIZE * 0.62)
    mark = render_brand_mark(inner_size, on_transparent=True)
    offset = (SIZE - inner_size) // 2
    fg.paste(mark, (offset, offset), mark)
    fg.save(OUT_DIR / "icon_foreground.png", "PNG")

    return OUT_DIR / "icon.png", OUT_DIR / "icon_foreground.png"


if __name__ == "__main__":
    a, b = make()
    print(f"Wrote {a}")
    print(f"Wrote {b}")
