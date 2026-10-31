#!/usr/bin/env python3
"""Renders a mock of HallPass's main window for the apps-site catalogue.

SwiftUI cannot run on the Linux host that maintains the catalogue, so this
script re-draws the loaded editor layout from Sources/HallPass/ContentView.swift
with PIL instead of capturing the real view. The drawn data is the preview
mode's invented CIDR list; keep it in step with the SwiftUI layout when the
interface changes. Output: dist/hallpass.png (2x scale).
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os
from pathlib import Path

S = 2  # 2x scale like the other catalogue captures
W, H = 1320, 904
PAD = 40
OUT = os.path.join(os.path.dirname(__file__), "..", "dist", "hallpass.png")

ACCENT = (33, 110, 89)          # Palette.green, light appearance
WINDOW_BG = (236, 236, 236)
SIDEBAR_BG = (231, 233, 232)
SURFACE = (255, 255, 255)
HAIRLINE = (0, 0, 0, 18)
TEXT = (29, 29, 31)
SECONDARY = (110, 110, 115)
TERTIARY = (161, 161, 166)

FONT_DIRS = [
    "/usr/share/fonts/truetype/dejavu",
    "/usr/share/fonts/dejavu",
    "/usr/share/fonts/TTF",
]

def font(name, size):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size * S)
    return ImageFont.load_default()

F_TITLE = font("DejaVuSans-Bold.ttf", 23)
F_BRAND = font("DejaVuSans-Bold.ttf", 20)
F_SEMI = font("DejaVuSans-Bold.ttf", 12)
F_MED = font("DejaVuSans.ttf", 12)
F_SMALL = font("DejaVuSans.ttf", 11)
F_TINY = font("DejaVuSans.ttf", 10)
F_TINYB = font("DejaVuSans-Bold.ttf", 10)
F_MONO = font("DejaVuSansMono.ttf", 13)
F_MONO_COUNT = font("DejaVuSansMono-Bold.ttf", 10)
F_CHROME = font("DejaVuSans-Bold.ttf", 13)

def sc(v):
    return int(round(v * S))

def rounded(draw, box, r, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=sc(r), fill=fill, outline=outline, width=width)

def text_w(draw, s, f):
    return draw.textlength(s, font=f)

def draw_wifi(draw, x, y, size, color):
    for i, frac in enumerate((1.0, 0.68, 0.36)):
        r = size * frac / 2
        box = [x + size / 2 - r, y + size / 2 - r, x + size / 2 + r, y + size / 2 + r]
        draw.arc(box, start=225, end=315, fill=color, width=sc(1.4))
    draw.ellipse([x + size / 2 - sc(1.6), y + size / 2 + sc(3.4), x + size / 2 + sc(1.6), y + size / 2 + sc(6.6)], fill=color)

def draw_cable(draw, x, y, size, color):
    draw.line([x + size * 0.1, y + size * 0.5, x + size * 0.38, y + size * 0.5], fill=color, width=sc(1.4))
    rounded(draw, [x + size * 0.38, y + size * 0.32, x + size * 0.62, y + size * 0.68], 1.4, outline=color, width=sc(1.4))
    draw.line([x + size * 0.62, y + size * 0.42, x + size * 0.72, y + size * 0.42], fill=color, width=sc(1.4))
    draw.line([x + size * 0.62, y + size * 0.58, x + size * 0.72, y + size * 0.58], fill=color, width=sc(1.4))

def draw_info(draw, cx, cy, r, color):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=sc(1.1))
    draw.ellipse([cx - sc(0.9), cy - r + sc(2.6), cx + sc(0.9), cy - r + sc(4.4)], fill=color)
    draw.line([cx, cy - r + sc(6), cx, cy + r - sc(2.6)], fill=color, width=sc(1.4))

def draw_minus_circle(draw, cx, cy, r, color):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=sc(1.1))
    draw.line([cx - r + sc(3.4), cy, cx + r - sc(3.4), cy], fill=color, width=sc(1.4))

def draw_clock_arrow(draw, cx, cy, r, color):
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=40, end=340, fill=color, width=sc(1.3))
    a = math.radians(340)
    tx, ty = cx + r * math.cos(a), cy + r * math.sin(a)
    draw.polygon([(tx - sc(3), ty - sc(1)), (tx + sc(1.5), ty - sc(4)), (tx + sc(1), ty + sc(3))], fill=color)
    draw.line([cx, cy, cx, cy - sc(3.6)], fill=color, width=sc(1.2))
    draw.line([cx, cy, cx + sc(2.6), cy], fill=color, width=sc(1.2))

def draw_reload(draw, cx, cy, r, color):
    draw.arc([cx - r, cy - r, cx + r, cy + r], start=45, end=350, fill=color, width=sc(1.5))
    a = math.radians(45)
    tx, ty = cx + r * math.cos(a), cy + r * math.sin(a)
    draw.polygon([(tx + sc(1), ty - sc(5)), (tx + sc(5), ty + sc(2)), (tx - sc(1), ty + sc(3))], fill=color)

def draw_ticket_mark(draw, x, y, size):
    # ContentView's TicketMark loads the bundled .icns; the build derives it
    # from assets/HallPass-icon.png. Falls back to the plain ticket glyph.
    icon_path = Path(__file__).resolve().parent.parent / "assets" / "HallPass-icon.png"
    if icon_path.exists():
        icon = Image.open(icon_path).convert("RGBA").resize((int(size), int(size)), Image.LANCZOS)
        img.paste(icon, (int(x), int(y)), icon)
        return
    cx, cy = x + size / 2, y + size / 2
    ticket = Image.new("RGBA", (sc(40), sc(40)), (0, 0, 0, 0))
    td = ImageDraw.Draw(ticket)
    rounded(td, [sc(8), sc(14), sc(32), sc(26)], 2.4, fill=ACCENT + (255,))
    ticket = ticket.rotate(20, resample=Image.BICUBIC, expand=False)
    img.paste(ticket, (int(cx - sc(20)), int(cy - sc(20))), ticket)

img = Image.new("RGBA", (W + PAD * 2, H + PAD * 2), (0, 0, 0, 0))
shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle(
    [PAD, PAD + sc(4), PAD + W, PAD + H + sc(6)], radius=sc(11), fill=(0, 0, 0, 60))
shadow = shadow.filter(ImageFilter.GaussianBlur(sc(6)))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

rounded(draw, [PAD, PAD, PAD + W, PAD + H], 10, fill=WINDOW_BG)

# Window chrome
for i, c in enumerate(((255, 95, 87), (254, 188, 46), (40, 200, 64))):
    cx = PAD + sc(20) + i * sc(20)
    draw.ellipse([cx - sc(6), PAD + sc(15), cx + sc(6), PAD + sc(27)], fill=c)
title = "HallPass"
tw = text_w(draw, title, F_CHROME)
draw.text((PAD + W / 2 - tw / 2, PAD + sc(13)), title, font=F_CHROME, fill=SECONDARY)

SB = 180
draw.rectangle([PAD, PAD + sc(28), PAD + sc(SB), PAD + H], fill=SIDEBAR_BG)
# sidebar rounded corner fix (bottom-left)
draw.pieslice([PAD, PAD + H - sc(20), PAD + sc(20), PAD + H], 90, 180, fill=SIDEBAR_BG)

draw_ticket_mark(draw, PAD + sc(16), PAD + sc(43), sc(32))
draw.text((PAD + sc(57), PAD + sc(48)), "HallPass", font=F_BRAND, fill=TEXT)

rows = [("WLAN", "wifi", "3", True), ("Ethernet", "cable", "2", False)]
ry = PAD + sc(107)
for label, icon, count, selected in rows:
    if selected:
        rounded(draw, [PAD + sc(9), ry, PAD + sc(SB - 9), ry + sc(33)], 8, fill=(233, 240, 238))
    iy = ry + sc(8)
    if icon == "wifi":
        draw_wifi(draw, PAD + sc(14), iy, sc(16), TEXT)
    else:
        draw_cable(draw, PAD + sc(14), iy, sc(16), TEXT)
    draw.text((PAD + sc(40), ry + sc(9)), label, font=F_MED, fill=TEXT)
    cw = text_w(draw, count, F_MONO_COUNT)
    draw.text((PAD + sc(SB - 16) - cw, ry + sc(11)), count, font=F_MONO_COUNT, fill=SECONDARY)
    ry += sc(38)

by = PAD + H - sc(40)
draw_clock_arrow(draw, PAD + sc(23), by + sc(8), sc(6.5), TEXT)
draw.text((PAD + sc(36), by + sc(1)), "Backups", font=F_SMALL, fill=TEXT)

draw.line([PAD + sc(SB), PAD + sc(28), PAD + sc(SB), PAD + H], fill=HAIRLINE, width=1)

MX = PAD + sc(SB + 28)
MW = W - sc(SB + 56)
hy = PAD + sc(43)
draw.text((MX, hy), "Netzfreigaben", font=F_TITLE, fill=TEXT)
hw = text_w(draw, "Netzfreigaben", F_TITLE)
draw_info(draw, MX + hw + sc(15), hy + sc(15), sc(7), SECONDARY)

pv = "Vorschau"
pv_w = text_w(draw, pv, F_TINYB)
pw = pv_w + sc(58)
rounded(draw, [MX + MW - pw, hy + sc(3), MX + MW, hy + sc(25)], 11, outline=(196, 222, 213), width=sc(1.2))
draw.text((MX + MW - pw + sc(10), hy + sc(8)), pv, font=F_TINYB, fill=ACCENT)
draw_info(draw, MX + MW - pw + pv_w + sc(22), hy + sc(14), sc(6), SECONDARY)
xc, yc = MX + MW - sc(13), hy + sc(14)
draw.line([xc - sc(3), yc - sc(3), xc + sc(3), yc + sc(3)], fill=TEXT, width=sc(1.4))
draw.line([xc - sc(3), yc + sc(3), xc + sc(3), yc - sc(3)], fill=TEXT, width=sc(1.4))

card_y = hy + sc(50)
card_h = sc(300)
rounded(draw, [MX, card_y, MX + MW, card_y + card_h], 13, fill=SURFACE, outline=(0, 0, 0, 16), width=1)

draw.text((MX + sc(16), card_y + sc(15)), "IP-Bereiche", font=F_SEMI, fill=TEXT)
iw = text_w(draw, "IP-Bereiche", F_SEMI)
draw.text((MX + sc(22) + iw, card_y + sc(16)), "3", font=F_SMALL, fill=SECONDARY)
add = "+ Hinzufügen"
aw = text_w(draw, add, F_SMALL) + sc(18)
rounded(draw, [MX + MW - sc(12) - aw, card_y + sc(11), MX + MW - sc(12), card_y + sc(33)], 6, outline=(0, 0, 0, 40), width=1)
draw.text((MX + MW - sc(12) - aw + sc(9), card_y + sc(15)), add, font=F_SMALL, fill=TEXT)

draw.line([MX, card_y + sc(46), MX + MW, card_y + sc(46)], fill=HAIRLINE, width=1)

entries = [("169.254.0.0/16", "IPv4", False), ("192.168.1.0/24", "IPv4", True), ("fe80::/10", "IPv6", False)]
ey = card_y + sc(46)
for i, (cidr, fam, is_new) in enumerate(entries):
    cy = ey + sc(17)
    draw.text((MX + sc(16), cy + sc(4)), cidr, font=F_MONO, fill=TEXT)
    fam_w = text_w(draw, fam, F_TINY)
    right = MX + MW - sc(16)
    minus_x = right - sc(15)
    draw_minus_circle(draw, minus_x, cy + sc(11), sc(7), SECONDARY)
    if is_new:
        draw.ellipse([minus_x - sc(18), cy + sc(8), minus_x - sc(13), cy + sc(13)], fill=ACCENT)
        fam_x = minus_x - sc(18) - fam_w - sc(14)
    else:
        fam_x = minus_x - fam_w - sc(14)
    draw.text((fam_x, cy + sc(7)), fam, font=F_TINY, fill=TERTIARY)
    if i < len(entries) - 1:
        ey += sc(50)
        draw.line([MX + sc(16), ey, MX + MW, ey], fill=HAIRLINE, width=1)

fy = card_y + card_h + sc(22)
draw_reload(draw, MX + sc(10), fy + sc(12), sc(7), SECONDARY)
draw.text((MX + sc(26), fy + sc(7)), "Ungespeichert", font=F_TINY, fill=SECONDARY)
apply = "Änderungen prüfen"
apw = text_w(draw, apply, F_MED) + sc(28)
rounded(draw, [MX + MW - apw, fy, MX + MW, fy + sc(28)], 6, fill=ACCENT)
draw.text((MX + MW - apw + sc(14), fy + sc(6)), apply, font=F_MED, fill=(255, 255, 255))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(OUT)
