#!/usr/bin/env python3
"""
Generate the Scene app icon at 1024x1024.
Recreates the design: dark teal rounded-rect with 4 frosted-glass window panes.
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
ICON_RADIUS = int(SIZE * 0.22)  # macOS superellipse approximation

# --- Colour palette (sampled from existing icon) ---
BG_TOP = (18, 50, 62)       # dark navy-teal top
BG_MID = (25, 75, 90)       # mid teal
BG_BOT = (15, 90, 100)      # slightly lighter teal bottom
GLOW_CENTER = (50, 140, 155, 80)  # subtle aqua glow
PANE_FILL = (140, 195, 210, 55)   # frosted glass base
PANE_BORDER = (170, 215, 225, 110) # glass edge highlight
PANE_SHINE = (200, 235, 240, 45)  # top-left shine


def rounded_rect_mask(size, radius):
    """Create an antialiased rounded-rect mask at 4x then downscale."""
    scale = 4
    big = Image.new("L", (size[0] * scale, size[1] * scale), 0)
    d = ImageDraw.Draw(big)
    d.rounded_rectangle(
        [0, 0, big.width - 1, big.height - 1],
        radius=radius * scale,
        fill=255,
    )
    return big.resize(size, Image.LANCZOS)


def draw_gradient_bg(img):
    """Vertical gradient background with a subtle radial glow."""
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        t = y / h
        if t < 0.5:
            s = t / 0.5
            r = int(BG_TOP[0] + (BG_MID[0] - BG_TOP[0]) * s)
            g = int(BG_TOP[1] + (BG_MID[1] - BG_TOP[1]) * s)
            b = int(BG_TOP[2] + (BG_MID[2] - BG_TOP[2]) * s)
        else:
            s = (t - 0.5) / 0.5
            r = int(BG_MID[0] + (BG_BOT[0] - BG_MID[0]) * s)
            g = int(BG_MID[1] + (BG_BOT[1] - BG_MID[1]) * s)
            b = int(BG_MID[2] + (BG_BOT[2] - BG_MID[2]) * s)
        for x in range(w):
            pixels[x, y] = (r, g, b, 255)

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = int(w * 0.55), int(h * 0.48)
    for i in range(60, 0, -1):
        radius = int(w * 0.28 * (i / 60))
        alpha = int(GLOW_CENTER[3] * (i / 60) * 0.4)
        col = (GLOW_CENTER[0], GLOW_CENTER[1], GLOW_CENTER[2], alpha)
        gd.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=col,
        )
    img.alpha_composite(glow)


def draw_pane(canvas, x, y, w, h, radius):
    """Draw a single frosted-glass pane with border and shine."""
    pane = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(pane)

    d.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=PANE_FILL)

    d.rounded_rectangle(
        [x, y, x + w, y + h],
        radius=radius,
        fill=None,
        outline=PANE_BORDER,
        width=2,
    )

    shine = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    shine_h = int(h * 0.35)
    sd.rounded_rectangle(
        [x + 4, y + 4, x + w - 4, y + shine_h],
        radius=max(radius - 4, 4),
        fill=PANE_SHINE,
    )
    shine = shine.filter(ImageFilter.GaussianBlur(radius=8))
    pane.alpha_composite(shine)

    canvas.alpha_composite(pane)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_gradient_bg(bg)

    mask = rounded_rect_mask((SIZE, SIZE), ICON_RADIUS)
    bg_arr = bg.split()
    bg = Image.merge("RGBA", (bg_arr[0], bg_arr[1], bg_arr[2], mask))
    img.alpha_composite(bg)

    border_overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border_overlay)
    bd.rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1],
        radius=ICON_RADIUS,
        fill=None,
        outline=(80, 140, 160, 60),
        width=3,
    )
    img.alpha_composite(border_overlay)

    margin = int(SIZE * 0.16)
    gap = int(SIZE * 0.035)
    pane_radius = int(SIZE * 0.04)
    inner_w = SIZE - 2 * margin
    inner_h = SIZE - 2 * margin

    col_split = 0.48
    row_split = 0.48
    left_w = int(inner_w * col_split - gap / 2)
    right_w = inner_w - left_w - gap
    top_h = int(inner_h * row_split - gap / 2)
    bot_h = inner_h - top_h - gap

    panes = [
        (margin, margin, left_w, top_h),                                  # top-left
        (margin + left_w + gap, margin, right_w, top_h),                  # top-right
        (margin, margin + top_h + gap, left_w, bot_h),                    # bottom-left
        (margin + left_w + gap, margin + top_h + gap, right_w, bot_h),    # bottom-right
    ]

    for (px, py, pw, ph) in panes:
        draw_pane(img, px, py, pw, ph, pane_radius)

    out_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "SceneApp", "SceneApp", "Assets.xcassets", "AppIcon.appiconset",
    )
    out_path = os.path.join(out_dir, "icon_512x512@2x.png")
    img.save(out_path, "PNG")
    print(f"Saved 1024x1024 icon to {out_path}")

    source_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "icon_1024x1024.png",
    )
    img.save(source_path, "PNG")
    print(f"Saved source icon to {source_path}")


if __name__ == "__main__":
    main()
