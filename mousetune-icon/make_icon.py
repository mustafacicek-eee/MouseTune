from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, os
S = 4096
k = S / 1024

def rr_mask(box, r):
    m = Image.new("L", (S, S), 0); ImageDraw.Draw(m).rounded_rectangle([v*k for v in box], radius=r*k, fill=255); return m

def vgrad(top, bot):
    g = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y/255; g.putpixel((0, y), tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    return g.resize((S, S))

ACCENT = (56, 189, 248)  # sky blue; deliberately not a vendor brand color
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
tile = rr_mask((100, 100, 924, 924), 185)
bg = vgrad((30, 34, 38), (9, 11, 13)).convert("RGBA")
glow = Image.new("L", (S, S), 0); ImageDraw.Draw(glow).ellipse([v*k for v in (300, 330, 724, 820)], fill=120)
glow = glow.filter(ImageFilter.GaussianBlur(110*k))
bg = Image.composite(Image.new("RGBA", (S, S), ACCENT+(255,)), bg, glow.point(lambda v: int(v*0.55)))
icon.paste(bg, (0, 0), tile)
edge = ImageChops.subtract(tile, rr_mask((104, 104, 920, 920), 181))
icon.paste(Image.new("RGBA", (S, S), (255, 255, 255, 38)), (0, 0), edge)

body = Image.new("L", (S, S), 0); d = ImageDraw.Draw(body)
pts = []
top, bot = 236, 800
for i in range(401):
    t = i/400; y = top + (bot-top)*t
    u = abs(2*t-1); hw = 176 * (1 - u**2.6)**(1/2.6) * (0.90 + 0.10*t)
    pts.append((512+hw, y))
pts += [(1024-x, y) for x, y in reversed(pts)]
d.polygon([(x*k, y*k) for x, y in pts], fill=255)
body = body.filter(ImageFilter.GaussianBlur(2*k))

g2 = body.filter(ImageFilter.GaussianBlur(22*k)).point(lambda v: int(v*0.85))
icon = Image.alpha_composite(icon, Image.merge("RGBA", (*[Image.new("L", (S, S), c) for c in ACCENT], ImageChops.multiply(g2, tile))))
shell = vgrad((58, 63, 69), (20, 22, 25)).convert("RGBA")
icon.paste(shell, (0, 0), body)
inner = body.filter(ImageFilter.MinFilter(int(14*k) | 1))
rim = ImageChops.subtract(body, inner)
icon.paste(Image.new("RGBA", (S, S), ACCENT+(255,)), (0, 0), rim)

d2 = Image.new("L", (S, S), 0); dd = ImageDraw.Draw(d2)
dd.line([(512*k, 240*k), (512*k, 452*k)], fill=255, width=int(9*k))
dd.arc([v*k for v in (300, 300, 724, 470)], start=15, end=165, fill=255, width=int(8*k))
d2 = ImageChops.multiply(d2, inner)
icon.paste(Image.new("RGBA", (S, S), (10, 11, 13, 255)), (0, 0), d2)

wheel = Image.new("L", (S, S), 0)
ImageDraw.Draw(wheel).rounded_rectangle([v*k for v in (493, 300, 531, 396)], radius=18*k, fill=255)
wg = wheel.filter(ImageFilter.GaussianBlur(10*k))
icon = Image.alpha_composite(icon, Image.merge("RGBA", (*[Image.new("L", (S, S), c) for c in ACCENT], wg.point(lambda v: int(v*0.9)))))
icon.paste(Image.new("RGBA", (S, S), ACCENT+(255,)), (0, 0), wheel)

gloss = Image.new("L", (S, S), 0)
ImageDraw.Draw(gloss).ellipse([v*k for v in (380, 262, 600, 420)], fill=60)
gloss = ImageChops.multiply(gloss.filter(ImageFilter.GaussianBlur(30*k)), inner)
icon.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), gloss)

a = ImageChops.multiply(icon.getchannel("A"), tile); icon.putalpha(a)
master = icon.resize((1024, 1024), Image.LANCZOS)
master.save("icon_1024.png")
sizes = {"icon_16x16.png":16,"icon_16x16@2x.png":32,"icon_32x32.png":32,"icon_32x32@2x.png":64,"icon_128x128.png":128,"icon_128x128@2x.png":256,"icon_256x256.png":256,"icon_256x256@2x.png":512,"icon_512x512.png":512,"icon_512x512@2x.png":1024}
os.makedirs("appiconset", exist_ok=True)
for n, s in sizes.items(): master.resize((s, s), Image.LANCZOS).save(f"appiconset/{n}")

T = 44*8; m = Image.new("L", (T, T), 0); md = ImageDraw.Draw(m); u = T/44
md.rounded_rectangle([13*u, 3*u, 31*u, 26*u], radius=9*u, fill=255)
md.ellipse([12.2*u, 13*u, 31.8*u, 41*u], fill=255)
hole = Image.new("L", (T, T), 0); hd = ImageDraw.Draw(hole)
hd.rounded_rectangle([16.2*u, 6.2*u, 27.8*u, 24*u], radius=6*u, fill=255)
hd.ellipse([15.4*u, 15*u, 28.6*u, 37.8*u], fill=255)
m = ImageChops.subtract(m, hole)
md = ImageDraw.Draw(m)
md.rounded_rectangle([20.4*u, 8.5*u, 23.6*u, 15.5*u], radius=1.6*u, fill=255)
md.line([(22*u, 3*u), (22*u, 8*u)], fill=255, width=int(2.4*u))
tpl = Image.new("RGBA", (T, T), (0, 0, 0, 0)); tpl.putalpha(m); tpl = tpl.resize((44, 44), Image.LANCZOS)
tpl.save("menu-template.png")
print("ok")
