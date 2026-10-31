"""Tiny frame-by-frame video engine for vertical (9:16) TikTok explainers.

Every frame is drawn with Pillow and piped as raw RGB into ffmpeg, so the
only requirements are Python 3, Pillow and an ffmpeg binary with libx264.
"""

from __future__ import annotations

import math
import os
import re
import subprocess
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Callable

from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
FPS = 30

# TikTok overlays its own UI: keep important content inside this box.
SAFE_L, SAFE_R = 60, 960 + 60  # right-side buttons sit over ~x>960 near the bottom
SAFE_TOP, SAFE_BOTTOM = 170, 1500

# ----------------------------------------------------------------------------
# Palette
# ----------------------------------------------------------------------------
BG_TOP = (9, 12, 26)
BG_BOTTOM = (20, 26, 52)
INK = (236, 240, 250)
MUTED = (148, 160, 190)
FAINT = (70, 82, 120)
PANEL = (17, 22, 42)
PANEL_EDGE = (44, 54, 92)
TEAL = (45, 212, 191)
AMBER = (251, 191, 36)
PINK = (244, 114, 182)
VIOLET = (167, 139, 250)
RED = (248, 113, 113)
GREEN = (74, 222, 128)
ORANGE = (251, 146, 60)
SKY = (56, 189, 248)

# ----------------------------------------------------------------------------
# Fonts
# ----------------------------------------------------------------------------
_FONT_FILES = {
    "display": ["/usr/share/fonts/opentype/inter/InterDisplay-Black.otf", "DejaVuSans-Bold.ttf"],
    "bold": ["/usr/share/fonts/opentype/inter/Inter-Bold.otf", "DejaVuSans-Bold.ttf"],
    "semibold": ["/usr/share/fonts/opentype/inter/Inter-SemiBold.otf", "DejaVuSans-Bold.ttf"],
    "regular": ["/usr/share/fonts/opentype/inter/Inter-Medium.otf", "DejaVuSans.ttf"],
    "mono": ["/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Medium.ttf", "DejaVuSansMono.ttf"],
    "monobold": ["/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf", "DejaVuSansMono-Bold.ttf"],
}


@lru_cache(maxsize=None)
def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    for path in _FONT_FILES[kind]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


# ----------------------------------------------------------------------------
# Easing / timing helpers
# ----------------------------------------------------------------------------
def clamp01(x: float) -> float:
    return 0.0 if x < 0 else 1.0 if x > 1 else x


def ease_out(x: float) -> float:
    x = clamp01(x)
    return 1 - (1 - x) ** 3


def ease_in_out(x: float) -> float:
    x = clamp01(x)
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def ease_back(x: float) -> float:
    x = clamp01(x)
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def prog(t: float, start: float, dur: float, ease=ease_out) -> float:
    if dur <= 0:
        return 1.0 if t >= start else 0.0
    return ease((t - start) / dur)


def lerp(a, b, p):
    if isinstance(a, tuple):
        return tuple(lerp(x, y, p) for x, y in zip(a, b))
    return a + (b - a) * p


def rgba(color, alpha: float = 1.0):
    return (int(color[0]), int(color[1]), int(color[2]), int(255 * clamp01(alpha)))


# ----------------------------------------------------------------------------
# Drawing surface: Pillow ignores the alpha of text fills on RGB images, so
# translucent text is rendered through a mask instead.
# ----------------------------------------------------------------------------
class Canvas(ImageDraw.ImageDraw):
    def __init__(self, im):
        super().__init__(im, "RGBA")

    def text(self, xy, text, fill=None, font=None, anchor=None, **kw):
        if fill is None or len(fill) < 4 or fill[3] >= 255:
            return super().text(xy, text, fill=fill, font=font, anchor=anchor, **kw)
        if fill[3] <= 0 or not text:
            return None
        x0, y0, x1, y1 = (int(v) for v in self.textbbox(xy, text, font=font, anchor=anchor))
        x0, y0, x1, y1 = x0 - 2, y0 - 2, x1 + 2, y1 + 2
        mask = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(mask).text((xy[0] - x0, xy[1] - y0), text, fill=fill[3], font=font, anchor=anchor, **kw)
        self._image.paste(tuple(fill[:3]), (x0, y0, x1, y1), mask)
        return None


# ----------------------------------------------------------------------------
# Background
# ----------------------------------------------------------------------------
@lru_cache(maxsize=1)
def background() -> Image.Image:
    img = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(img)
    for y in range(H):
        px.line([(0, y), (W, y)], fill=tuple(int(c) for c in lerp(BG_TOP, BG_BOTTOM, y / H)))
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, W, 60):
        d.line([(x, 0), (x, H)], fill=(255, 255, 255, 7))
    for y in range(0, H, 60):
        d.line([(0, y), (W, y)], fill=(255, 255, 255, 7))
    # soft glows
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    for r in range(520, 0, -8):
        a = int(20 * (1 - r / 520) ** 2)
        g.ellipse([W - 120 - r, 260 - r, W - 120 + r, 260 + r], fill=(45, 212, 191, a))
        g.ellipse([80 - r, H - 380 - r, 80 + r, H - 380 + r], fill=(167, 139, 250, a))
    img.paste(glow, (0, 0), glow)
    return img


# ----------------------------------------------------------------------------
# Rich text: words wrapped in *asterisks* are drawn in the accent colour.
# ----------------------------------------------------------------------------
def _parse_rich(text: str):
    words, cur, seg, accent = [], [], "", False
    for ch in text:
        if ch == "*":
            if seg:
                cur.append((seg, accent))
                seg = ""
            accent = not accent
        elif ch == " ":
            if seg:
                cur.append((seg, accent))
                seg = ""
            if cur:
                words.append(cur)
                cur = []
        else:
            seg += ch
    if seg:
        cur.append((seg, accent))
    if cur:
        words.append(cur)
    return words


def _layout_rich(text: str, f, max_w: int):
    space = f.getlength(" ")
    lines, line, line_w = [], [], 0.0
    for paragraph in text.split("\n"):
        for word in _parse_rich(paragraph):
            ww = sum(f.getlength(s) for s, _ in word)
            extra = ww if not line else line_w + space + ww
            if line and extra > max_w:
                lines.append((line, line_w))
                line, line_w = [word], ww
            else:
                line.append(word)
                line_w = extra
        lines.append((line, line_w))
        line, line_w = [], 0.0
    return lines, space


def rich_text(d, text, cx, y, size=78, kind="display", color=INK, accent=TEAL,
              alpha=1.0, max_w=900, line_gap=1.12, align="center", x=None):
    """Draw wrapped rich text; returns total height."""
    f = font(kind, size)
    lines, space = _layout_rich(text, f, max_w)
    lh = size * line_gap
    for i, (line, lw) in enumerate(lines):
        if align == "center":
            xx = cx - lw / 2
        else:
            xx = x
        yy = y + i * lh
        for wi, word in enumerate(line):
            if wi:
                xx += space
            for seg, acc in word:
                d.text((xx, yy), seg, font=f, fill=rgba(accent if acc else color, alpha))
                xx += f.getlength(seg)
    return len(lines) * lh


def headline(d, t, text, y=250, size=76, start=0.0, accent=TEAL, max_w=920, color=INK):
    p = prog(t, start, 0.45)
    return rich_text(d, text, W // 2, y + (1 - p) * 40, size=size, alpha=p,
                     accent=accent, max_w=max_w, color=color)


def caption(d, t, text, y, start=0.0, size=40, color=MUTED, accent=AMBER, max_w=900, kind="semibold"):
    p = prog(t, start, 0.4)
    return rich_text(d, text, W // 2, y + (1 - p) * 24, size=size, kind=kind,
                     alpha=p, color=color, accent=accent, max_w=max_w)


def chip(d, text, x, y, color=TEAL, alpha=1.0, size=30, center=False):
    f = font("bold", size)
    tw = f.getlength(text)
    pad_x, h = 22, size + 22
    if center:
        x = x - (tw + 2 * pad_x) / 2
    d.rounded_rectangle([x, y, x + tw + 2 * pad_x, y + h], radius=h // 2,
                        fill=rgba(color, 0.16 * alpha), outline=rgba(color, 0.8 * alpha), width=2)
    d.text((x + pad_x, y + h / 2), text, font=f, fill=rgba(color, alpha), anchor="lm")
    return tw + 2 * pad_x


def cell(d, box, text, fill=PANEL, text_color=INK, alpha=1.0, size=34, kind="monobold",
         outline=PANEL_EDGE, radius=14):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=rgba(fill, alpha),
                        outline=rgba(outline, alpha), width=2)
    if text:
        f = font(kind, size)
        while f.getlength(text) > (x1 - x0) - 16 and size > 16:
            size -= 2
            f = font(kind, size)
        d.text(((x0 + x1) / 2, (y0 + y1) / 2), text, font=f, fill=rgba(text_color, alpha), anchor="mm")


def arrow(d, x0, y0, x1, y1, color=MUTED, alpha=1.0, width=6, head=22):
    d.line([(x0, y0), (x1, y1)], fill=rgba(color, alpha), width=width)
    ang = math.atan2(y1 - y0, x1 - x0)
    pts = [(x1, y1),
           (x1 - head * math.cos(ang - 0.45), y1 - head * math.sin(ang - 0.45)),
           (x1 - head * math.cos(ang + 0.45), y1 - head * math.sin(ang + 0.45))]
    d.polygon(pts, fill=rgba(color, alpha))


def cross(d, cx, cy, r, color=RED, alpha=1.0, width=10):
    d.line([(cx - r, cy - r), (cx + r, cy + r)], fill=rgba(color, alpha), width=width)
    d.line([(cx - r, cy + r), (cx + r, cy - r)], fill=rgba(color, alpha), width=width)


def check(d, cx, cy, r, color=GREEN, alpha=1.0, width=10):
    d.line([(cx - r, cy), (cx - r * 0.3, cy + r * 0.7), (cx + r, cy - r * 0.7)],
           fill=rgba(color, alpha), width=width, joint="curve")


# ----------------------------------------------------------------------------
# T-SQL code panel with syntax highlighting + typewriter reveal
# ----------------------------------------------------------------------------
KEYWORDS = set("""
ADD AFTER ALTER AND AS ATOMIC BEGIN BY CATCH CHECK CLUSTERED CONSTRAINT CONTAINS CREATE DATABASE
DECLARE DELETE DISTINCT END EXEC EXECUTE EXISTS FILE FILEGROUP FOR FOREIGN FROM HASH IDENTITY IF
IN INDEX INSERT INTO ISOLATION JOIN KEY LANGUAGE LEVEL NATIVE_COMPILATION NONCLUSTERED NOT NULL
ON ORDER PATH PIVOT PRIMARY PRINT REFERENCES ROLLBACK SCHEMABINDING SELECT SET SNAPSHOT TABLE
THROW TO TRANSACTION TRIGGER TRY TYPE UNPIVOT UPDATE USE WHERE WITH XML MEMORY_OPTIMIZED
MEMORY_OPTIMIZED_DATA BUCKET_COUNT
""".split())
TYPES = set("INT INTEGER VARCHAR NVARCHAR CHAR DATE DATETIME DECIMAL NUMERIC FLOAT MAX".split())
FUNCS = set("STUFF QUOTENAME CAST CONVERT XACT_STATE COUNT".split())

_TOKEN_RE = re.compile(r"(--.*$)|(N?'[^']*'?)|(\[[^\]]*\]?)|(@\w+)|(\d+(?:\.\d+)?)|(\w+)|(\s+)|(.)")


def tokenize(line: str):
    out = []
    for m in _TOKEN_RE.finditer(line):
        comment, string, bracket, var, num, word, ws, other = m.groups()
        if comment:
            out.append((comment, FAINT))
        elif string:
            out.append((string, GREEN))
        elif bracket:
            out.append((bracket, TEAL))
        elif var:
            out.append((var, ORANGE))
        elif num:
            out.append((num, ORANGE))
        elif word:
            u = word.upper()
            if u in KEYWORDS:
                out.append((word, PINK))
            elif u in TYPES:
                out.append((word, SKY))
            elif u in FUNCS:
                out.append((word, AMBER))
            else:
                out.append((word, INK))
        elif ws:
            out.append((ws, INK))
        else:
            out.append((other, MUTED))
    return out


@dataclass
class CodePanel:
    code: str
    title: str = "query.sql"
    y: int = 520
    size: int = 32
    type_start: float = 0.3
    type_dur: float = 3.0
    highlights: list = field(default_factory=list)  # (line_idx_list, start_time, color)
    strikes: list = field(default_factory=list)  # (line_idx, start_time)
    x0: int = 50
    x1: int = 1030

    def __post_init__(self):
        self.lines = self.code.strip("\n").split("\n")
        self.tokens = [tokenize(line) for line in self.lines]
        self.total_chars = sum(len(line) for line in self.lines)

    @property
    def height(self):
        return 92 + len(self.lines) * int(self.size * 1.5) + 36

    def draw(self, d, t, alpha=1.0):
        f = font("mono", self.size)
        cw = f.getlength("M")
        lh = int(self.size * 1.5)
        p_in = prog(t, 0, 0.4)
        y = self.y + (1 - p_in) * 50
        a = alpha * p_in
        x0, x1 = self.x0, self.x1
        d.rounded_rectangle([x0, y, x1, y + self.height], radius=28, fill=rgba(PANEL, 0.94 * a),
                            outline=rgba(PANEL_EDGE, a), width=2)
        for i, c in enumerate((RED, AMBER, GREEN)):
            d.ellipse([x0 + 32 + i * 34, y + 30, x0 + 52 + i * 34, y + 50], fill=rgba(c, a))
        d.text((x0 + 150, y + 40), self.title, font=font("semibold", 28), fill=rgba(MUTED, a), anchor="lm")
        tx, ty = x0 + 34, y + 92

        # line highlights
        for idxs, start, color in self.highlights:
            hp = prog(t, start, 0.35)
            if hp <= 0:
                continue
            for li in idxs:
                ly = ty + li * lh - 6
                d.rounded_rectangle([x0 + 14, ly, x0 + 14 + (x1 - x0 - 28) * hp, ly + lh - 2],
                                    radius=10, fill=rgba(color, 0.16 * a))
                d.rectangle([x0 + 14, ly, x0 + 20, ly + lh - 2], fill=rgba(color, a))

        shown = int(self.total_chars * prog(t, self.type_start, self.type_dur, ease=lambda x: x))
        remaining = shown
        cursor = None
        for li, toks in enumerate(self.tokens):
            col = 0
            for text, color in toks:
                if remaining <= 0:
                    break
                part = text[:remaining]
                d.text((tx + col * cw, ty + li * lh), part, font=f, fill=rgba(color, a))
                col += len(part)
                remaining -= len(part)
            if remaining <= 0 and cursor is None:
                cursor = (tx + col * cw, ty + li * lh)
            if remaining <= 0:
                break
        if cursor and shown < self.total_chars and int(t * 3) % 2 == 0:
            d.rectangle([cursor[0], cursor[1], cursor[0] + cw * 0.6, cursor[1] + self.size * 1.1],
                        fill=rgba(TEAL, a))

        for li, start in self.strikes:
            sp = prog(t, start, 0.5)
            if sp <= 0:
                continue
            line = self.lines[li]
            lead = len(line) - len(line.lstrip())
            sx = tx + lead * cw
            ex = sx + (len(line) - lead) * cw * sp
            sy = ty + li * lh + self.size * 0.62
            d.line([(sx - 6, sy), (ex + 6, sy)], fill=rgba(RED, a), width=6)

    def line_y(self, li):
        return self.y + 92 + li * int(self.size * 1.5)


# ----------------------------------------------------------------------------
# Scenes / video
# ----------------------------------------------------------------------------
@dataclass
class Scene:
    dur: float
    draw: Callable  # draw(d, t) with t = seconds since scene start


@dataclass
class Video:
    slug: str
    title: str
    part: str
    scenes: list
    cover_time: float = 2.4

    @property
    def duration(self):
        return sum(s.dur for s in self.scenes)


def _overlay(d, video: Video, gt: float):
    chip(d, video.part, SAFE_L, 150, color=MUTED, size=26)
    # thin progress bar along the top of the safe area
    total = video.duration
    d.rounded_rectangle([SAFE_L, 120, W - SAFE_L, 128], radius=4, fill=(255, 255, 255, 22))
    d.rounded_rectangle([SAFE_L, 120, SAFE_L + (W - 2 * SAFE_L) * clamp01(gt / total), 128],
                        radius=4, fill=rgba(TEAL, 0.9))


def render_frame(video: Video, gt: float, prev_last=None):
    bg = background()
    # locate scene
    acc = 0.0
    for idx, scene in enumerate(video.scenes):
        if gt < acc + scene.dur or idx == len(video.scenes) - 1:
            lt = gt - acc
            break
        acc += scene.dur
    img = bg.copy()
    d = Canvas(img)
    scene.draw(d, lt)
    _overlay(d, video, gt)
    return img, idx, lt


def render(video: Video, out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{video.slug}.mp4")
    n_frames = int(round(video.duration * FPS))
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-shortest", "-map", "0:v", "-map", "1:a",
        "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p",
        "-profile:v", "high", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", out,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    fade = 0.22
    last_frames: dict[int, Image.Image] = {}
    cover_frame = int(video.cover_time * FPS)
    for i in range(n_frames):
        gt = i / FPS
        img, idx, lt = render_frame(video, gt)
        last_frames[idx] = img
        if idx > 0 and lt < fade and (idx - 1) in last_frames:
            img = Image.blend(last_frames[idx - 1], img, ease_in_out(lt / fade))
        if i == cover_frame:
            img.save(os.path.join(out_dir, f"{video.slug}_cover.png"))
        for k in list(last_frames):
            if k < idx - 1:
                del last_frames[k]
        proc.stdin.write(img.tobytes())
    proc.stdin.close()
    if proc.wait() != 0:
        raise RuntimeError(f"ffmpeg failed for {video.slug}")
    return out
