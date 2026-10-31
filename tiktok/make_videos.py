"""Render the "SQL from a real power-market pipeline" TikTok series.

Each episode explains one technique used in this repository's .sql files:

  1. UNPIVOT                    -> LMWFtbls.sql, 7 Tables combo .sql
  2. Duplicate-proof triggers   -> HourResOutCap.sql, LMWFtbls.sql
  3. Memory-optimized tables    -> R.L. Mem Opt.sql, R.L. Mem Opt Triggers.sql
  4. Dynamic PIVOT              -> R.L. Mem Opt Triggers.sql

Usage:
    python3 tiktok/make_videos.py            # render all episodes
    python3 tiktok/make_videos.py unpivot    # render matching episode(s)
"""

from __future__ import annotations

import os
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from engine import (  # noqa: E402
    AMBER, FAINT, GREEN, INK, MUTED, PANEL, PANEL_EDGE, PINK, RED, SKY, TEAL, VIOLET, W,
    CodePanel, Scene, Video, arrow, caption, cell, check, chip, cross, ease_back, ease_in_out,
    font, headline, lerp, prog, render, rgba, rich_text,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "videos")


# ----------------------------------------------------------------------------
# Shared scene builders
# ----------------------------------------------------------------------------
def hook_scene(dur, kicker, line1, line2, accent=TEAL):
    def draw(d, t):
        p = prog(t, 0.0, 0.4)
        chip(d, kicker, W // 2, 560 - (1 - p) * 20, color=accent, alpha=p, center=True)
        p1 = prog(t, 0.15, 0.5, ease_back)
        h = rich_text(d, line1, W // 2, 680 + (1 - p1) * 60, size=104, alpha=prog(t, 0.15, 0.3),
                      accent=accent, max_w=900, line_gap=1.08)
        caption(d, t, line2, 720 + h, start=1.1, size=52, color=INK, accent=accent, kind="bold")
    return Scene(dur, draw)


def outro_scene(dur, line1, next_up, accent=TEAL, label="NEXT UP", follow="Follow so you don't miss it"):
    def draw(d, t):
        headline(d, t, line1, y=640, size=84, accent=accent)
        p = prog(t, 0.7, 0.5, ease_back)
        if p > 0:
            y = 1040 + (1 - p) * 40
            d.rounded_rectangle([140, y, W - 140, y + 220], radius=36, fill=rgba(PANEL, 0.95 * min(1, p)),
                                outline=rgba(accent, min(1, p)), width=3)
            d.text((W // 2, y + 62), label, font=font("bold", 30), fill=rgba(MUTED, min(1, p)),
                   anchor="mm")
            rich_text(d, next_up, W // 2, y + 100, size=50, kind="bold", alpha=min(1, p), max_w=740)
        caption(d, t, follow, 1320, start=1.3, size=38)
    return Scene(dur, draw)


def code_scene(dur, title, panel: CodePanel, note=None, note_start=None, accent=TEAL, title_size=72):
    def draw(d, t):
        headline(d, t, title, y=250, size=title_size, accent=accent)
        panel.draw(d, t)
        if note:
            caption(d, t, note, panel.y + panel.height + 50, start=note_start or panel.type_start + panel.type_dur,
                    size=42)
    return Scene(dur, draw)


# ----------------------------------------------------------------------------
# Episode 1: UNPIVOT
# ----------------------------------------------------------------------------
def ep_unpivot() -> Video:
    regions = ["Coast", "East", "FarWest", "North"]
    values = ["11,482", "1,354", "2,671", "1,602"]

    wide_cols = [150, 190, 180, 210, 180]
    wide_x0 = (W - sum(wide_cols) - 4 * 8) // 2

    def wide_boxes(y, rows=1, rh=84):
        boxes = []
        for r in range(rows + 1):
            x = wide_x0
            row = []
            for cw in wide_cols:
                row.append((x, y + r * (rh + 8), x + cw, y + r * (rh + 8) + rh))
                x += cw + 8
            boxes.append(row)
        return boxes

    def problem(d, t):
        headline(d, t, "The weather-forecast feed has *one column per region*", y=260, size=70)
        hdr = ["HE"] + regions
        rows = [
            ["01:00"] + values,
            ["02:00", "11,107", "1,298", "2,644", "1,577"],
            ["03:00", "10,866", "1,262", "2,630", "1,551"],
        ]
        boxes = wide_boxes(640, rows=3)
        for c, box in enumerate(boxes[0]):
            p = prog(t, 0.4 + c * 0.08, 0.35)
            cell(d, box, hdr[c], fill=(30, 40, 75), text_color=TEAL if c else MUTED, alpha=p, size=32)
        for r, row in enumerate(rows):
            for c, box in enumerate(boxes[r + 1]):
                p = prog(t, 0.8 + r * 0.15 + c * 0.05, 0.35)
                cell(d, box, row[c], alpha=p, size=32, kind="mono")
        # "... + 4 more" ghost column hint
        p = prog(t, 1.8, 0.4)
        d.text((W // 2, 1040), "+ NorthCentral, SouthCentral, Southern, West ...", font=font("semibold", 34),
               fill=rgba(FAINT, p), anchor="mm")
        caption(d, t, "New region? *Schema change.*\nWant a total per region? *Ugly SQL.*", 1150, start=2.4,
                size=50, color=INK, accent=RED, kind="bold")

    panel = CodePanel(
        code="""
SELECT DeliveryDate, HourEnding,
       Regions, RegionData
FROM (SELECT DeliveryDate, HourEnding,
             [Coast], [East],
             [FarWest], [North]
      FROM inserted) P
UNPIVOT
( RegionData FOR Regions IN
  ([Coast], [East], [FarWest], [North])
) AS unpvt
""",
        title="LMWFtbls.sql  (trigger body)",
        y=520, type_dur=3.6,
        highlights=[([6, 7, 8, 9], 4.3, TEAL)],
    )

    def anim(d, t):
        headline(d, t, "Each column becomes *a row*", y=250, size=76)
        top = wide_boxes(470, rows=1)
        hdr = ["HE"] + regions
        row = ["01:00"] + values
        # wide table stays as the "source", fading slightly once used
        for c, box in enumerate(top[0]):
            used = prog(t, 1.0 + (c - 1) * 0.55, 0.6) if c else 0
            cell(d, box, hdr[c], fill=(30, 40, 75), text_color=TEAL if c else MUTED, alpha=1 - 0.6 * used,
                 size=32)
        for c, box in enumerate(top[1]):
            used = prog(t, 1.0 + (c - 1) * 0.55, 0.6) if c else 0
            cell(d, box, row[c], alpha=1 - 0.6 * used, size=32, kind="mono")

        # long table
        long_cols = [200, 300, 300]
        lx0 = (W - sum(long_cols) - 16) // 2
        ly0, rh = 800, 84

        def lbox(r, c):
            x = lx0 + sum(long_cols[:c]) + 8 * c
            y = ly0 + r * (rh + 8)
            return (x, y, x + long_cols[c], y + rh)

        p_hdr = prog(t, 0.4, 0.4)
        for c, name in enumerate(["HE", "Regions", "RegionData"]):
            cell(d, lbox(0, c), name, fill=(48, 34, 80), text_color=VIOLET, alpha=p_hdr, size=32,
                 kind="bold")
        for i in range(4):
            start = 1.0 + i * 0.55
            p = prog(t, start, 0.6, ease_in_out)
            if p <= 0:
                continue
            # HE copies straight down
            cell(d, lbox(i + 1, 0), "01:00", alpha=prog(t, start + 0.3, 0.3), size=32, kind="mono")
            # header name -> Regions column
            src_h = top[0][i + 1]
            dst_h = lbox(i + 1, 1)
            cell(d, lerp(src_h, dst_h, p), regions[i], fill=lerp((30, 40, 75), PANEL, p), text_color=TEAL,
                 size=32, outline=TEAL if p < 1 else PANEL_EDGE)
            # value -> RegionData column
            src_v = top[1][i + 1]
            dst_v = lbox(i + 1, 2)
            cell(d, lerp(src_v, dst_v, p), values[i], text_color=AMBER, size=32, kind="mono",
                 outline=AMBER if p < 1 else PANEL_EDGE)
        caption(d, t, "column *name* → Regions   ·   column *value* → RegionData", 1300, start=3.6, size=36)

    def bonus(d, t):
        headline(d, t, "Then *JOIN* a lookup table and store an ID", y=250, size=70)
        panel2 = CodePanel(
            code="""
FROM (...) P
UNPIVOT (RegionData FOR Regions IN
  ([Coast], [East], [FarWest], [North])
) AS unpvt
JOIN dbo.Regions rg
  ON rg.Regions = unpvt.Regions
""",
            title="LMWFtbls.sql  (TR_LMWF)", y=500, type_dur=1.8, highlights=[([4, 5], 2.3, VIOLET)],
        )
        panel2.draw(d, t)
        items = [
            ("New region = a new *row*", 2.8),
            ("Small *INT* keys, not repeated text", 3.4),
            ("Totals per region = one *GROUP BY*", 4.0),
        ]
        for i, (txt, st) in enumerate(items):
            p = prog(t, st, 0.4)
            y = 1000 + i * 120
            check(d, 130, y + 24, 20, alpha=p)
            rich_text(d, txt, 0, y, size=42, kind="bold", alpha=p, align="left", x=180, max_w=820,
                      accent=TEAL)

    return Video(
        slug="01_unpivot",
        title="UNPIVOT in 30 seconds",
        part="PART 1/4 · T-SQL",
        scenes=[
            hook_scene(3.2, "SQL IN 30 SECONDS", "Your table is *too wide.*", "One keyword fixes it."),
            Scene(5.0, problem),
            code_scene(7.0, "*UNPIVOT* turns columns into rows", panel,
                       note="Real trigger code from this repo", note_start=4.5),
            Scene(6.0, anim),
            Scene(5.6, bonus),
            outro_scene(3.6, "Save this for your next *ETL job*", "Triggers that *never* insert duplicates"),
        ],
    )


# ----------------------------------------------------------------------------
# Episode 2: duplicate-proof triggers
# ----------------------------------------------------------------------------
def ep_triggers() -> Video:
    def setup(d, t):
        headline(d, t, "Raw feed lands in a *staging table*.\nA trigger fills the lookups.", y=250, size=66)
        boxes = [
            ((140, 640, 940, 800), "LoadModelWeatherForecastRecieve", "raw rows from the feed", SKY),
            ((240, 1060, 840, 1220), "dbo.LoadModel", "one row per model", VIOLET),
        ]
        for i, (box, name, sub, color) in enumerate(boxes):
            p = prog(t, 0.4 + i * 1.0, 0.45, ease_back)
            if p <= 0:
                continue
            a = min(1, p)
            x0, y0, x1, y1 = box
            d.rounded_rectangle(box, radius=26, fill=rgba(PANEL, 0.95 * a), outline=rgba(color, a), width=3)
            d.text(((x0 + x1) / 2, y0 + 58), name, font=font("monobold", 34), fill=rgba(color, a), anchor="mm")
            d.text(((x0 + x1) / 2, y0 + 110), sub, font=font("semibold", 30), fill=rgba(MUTED, a), anchor="mm")
        pa = prog(t, 0.9, 0.5)
        if pa > 0:
            arrow(d, W // 2, 815, W // 2, 815 + 225 * pa, color=AMBER, alpha=1)
            d.text((W // 2 + 30, 930), "AFTER INSERT", font=font("monobold", 32), fill=rgba(AMBER, pa),
                   anchor="lm")
        caption(d, t, "Problem: the same model shows up *every hour*", 1330, start=2.0, size=44, color=INK,
                accent=RED, kind="bold")

    panel = CodePanel(
        code="""
CREATE TRIGGER TR_LModel
ON [dbo].[LoadModelWeatherForecastRecieve]
AFTER INSERT
AS
BEGIN
  INSERT INTO [dbo].[LoadModel] (Model)
  SELECT DISTINCT [Model] FROM inserted
  WHERE NOT EXISTS (
    SELECT * FROM [dbo].[LoadModel]
    WHERE [Model] = inserted.[Model])
END
""",
        title="LMWFtbls.sql", y=480, size=31, type_dur=3.4,
        highlights=[([6], 4.0, AMBER), ([7, 8, 9], 5.0, TEAL)],
    )

    def anim(d, t):
        phase2 = 4.2
        if t < phase2:
            headline(d, t, "*DISTINCT* drops dupes inside the batch", y=250, size=68, accent=AMBER)
        else:
            headline(d, t - phase2, "*NOT EXISTS* skips rows already stored", y=250, size=68)

        # columns
        lx, rx, cw, rh = 110, 600, 370, 96
        d.text((lx + cw / 2, 520), "inserted", font=font("monobold", 36), fill=rgba(SKY), anchor="mm")
        d.text((rx + cw / 2, 520), "dbo.LoadModel", font=font("monobold", 36), fill=rgba(VIOLET), anchor="mm")
        incoming = ["E", "M", "E1", "M"]
        existing = ["E", "A"]

        def lbox(i):
            return (lx, 580 + i * (rh + 14), lx + cw, 580 + i * (rh + 14) + rh)

        def rbox(i):
            return (rx, 580 + i * (rh + 14), rx + cw, 580 + i * (rh + 14) + rh)

        for i, m in enumerate(existing):
            cell(d, rbox(i), f"{i + 1}   {m}", text_color=INK, size=40)

        # step 1: duplicate "M" (index 3) is removed by DISTINCT
        dup_p = prog(t, 1.2, 0.6)
        # step 2: E rejected, M and E1 move into the lookup
        for i, m in enumerate(incoming):
            box = lbox(i)
            if i == 3:
                if dup_p < 1:
                    cell(d, box, m, outline=AMBER, text_color=AMBER, alpha=1 - dup_p * 0.85, size=40)
                    if dup_p > 0:
                        d.line([(box[0] + 30, (box[1] + box[3]) / 2), (box[0] + 30 + (cw - 60) * dup_p,
                                                                         (box[1] + box[3]) / 2)],
                               fill=rgba(AMBER), width=6)
                d.text((box[0] + cw / 2, box[3] + 40), "duplicate in batch", font=font("semibold", 30),
                       fill=rgba(AMBER, prog(t, 1.4, 0.4) * (1 - prog(t, phase2 - 0.4, 0.4))), anchor="mm")
                continue
            if i == 0:  # E already exists
                shake = 0
                pe = prog(t, phase2 + 0.4, 0.5, ease_in_out)
                back = prog(t, phase2 + 0.9, 0.4, ease_in_out)
                dx = (rx - lx - cw - 10) * (pe - back)
                if phase2 + 0.9 < t < phase2 + 1.3:
                    shake = 8 * ((int(t * 40) % 2) * 2 - 1)
                b = (box[0] + dx + shake, box[1], box[2] + dx + shake, box[3])
                rej = prog(t, phase2 + 0.9, 0.3)
                cell(d, b, m, outline=lerp(PANEL_EDGE, RED, rej), text_color=lerp(INK, RED, rej), size=40)
                if rej > 0:
                    cross(d, box[2] - 40, (box[1] + box[3]) / 2, 18, alpha=rej)
                continue
            # M (i=1) -> slot 2, E1 (i=2) -> slot 3
            slot = 2 if i == 1 else 3
            p = prog(t, phase2 + 1.4 + (i - 1) * 0.5, 0.7, ease_in_out)
            b = lerp(box, rbox(slot), p)
            label = m if p < 1 else f"{slot + 1}   {m}"
            cell(d, b, label, outline=lerp(PANEL_EDGE, GREEN, p), text_color=lerp(INK, GREEN, p), size=40)
            if p >= 1:
                check(d, rbox(slot)[2] - 44, (b[1] + b[3]) / 2, 16, alpha=prog(t, phase2 + 2.2 + i * 0.3, 0.3))

        caption(d, t, "Every model stored *exactly once*, no matter how often the feed repeats it",
                1110 + 4 * 0, start=phase2 + 3.0, size=42, color=INK, accent=GREEN, kind="bold")

    tip_panel = CodePanel(
        code="""
BEGIN CATCH
  IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;
  THROW;
  PRINT ' This Model already exists'
END CATCH
""",
        title="LMWFtbls.sql", y=560, size=32, type_dur=2.0,
        highlights=[([3], 2.4, AMBER)], strikes=[(4, 3.2)],
    )

    def tip(d, t):
        chip(d, "PRO TIP", W // 2, 230, color=AMBER, center=True, alpha=prog(t, 0, 0.3))
        headline(d, t, "Code after *THROW* never runs", y=320, size=72, accent=AMBER)
        tip_panel.draw(d, t)
        caption(d, t, "THROW ends the batch: that PRINT is dead code.\nPRINT *before* THROW, or drop it.",
                tip_panel.y + tip_panel.height + 60, start=3.8, size=38, color=INK, kind="bold")

    return Video(
        slug="02_dedupe_triggers",
        title="Triggers that never insert duplicates",
        part="PART 2/4 · T-SQL",
        scenes=[
            hook_scene(3.2, "SQL TRIGGERS", "Your trigger inserts *duplicates.*", "Here's the 2-line fix.",
                       accent=AMBER),
            Scene(4.6, setup),
            code_scene(7.0, "The fix: *DISTINCT* + *NOT EXISTS*", panel, title_size=68),
            Scene(8.6, anim),
            Scene(6.6, tip),
            outro_scene(3.6, "Idempotent loads = *sleep at night*", "Tables that live *in memory*"),
        ],
    )


# ----------------------------------------------------------------------------
# Episode 3: memory-optimized tables
# ----------------------------------------------------------------------------
def ep_inmemory() -> Video:
    step1 = CodePanel(
        code="""
ALTER DATABASE Project5
  ADD FILEGROUP pr_mod
  CONTAINS MEMORY_OPTIMIZED_DATA;

ALTER DATABASE Project5
  ADD FILE (name = 'pr_modfg',
            filename = 'C:\\pr_mod')
  TO FILEGROUP pr_mod;
""",
        title="R.L. Mem Opt.sql", y=520, type_dur=2.6, highlights=[([2], 3.0, TEAL)],
    )
    step2 = CodePanel(
        code="""
CREATE TABLE dbo.SettlementPoint (
  SettlementPointID INT IDENTITY
    PRIMARY KEY NONCLUSTERED,
  SettlementPoint VARCHAR(25) NOT NULL,
  SettlementPointTypeID INT NOT NULL
    INDEX IX_SettlementPTID
    NONCLUSTERED HASH
    WITH (BUCKET_COUNT = 40)
) WITH (MEMORY_OPTIMIZED = ON);
""",
        title="R.L. Mem Opt.sql", y=520, type_dur=3.2,
        highlights=[([8], 3.6, TEAL), ([5, 6, 7], 4.4, AMBER)],
    )
    step3 = CodePanel(
        code="""
CREATE TRIGGER dbo.INSERT_Set_Pnt_Type
ON [dbo].[RTDIndicativeLMP]
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT, UPDATE
AS
BEGIN ATOMIC WITH (
  TRANSACTION ISOLATION LEVEL = SNAPSHOT,
  LANGUAGE = N'us_english')
  INSERT INTO dbo.SettlementPointType ...
END
""",
        title="R.L. Mem Opt Triggers.sql", y=500, size=31, type_dur=3.0,
        highlights=[([2], 3.4, TEAL), ([5, 6, 7], 4.2, VIOLET)],
    )

    def hashing(d, t):
        headline(d, t, "A *HASH* index is a row of buckets", y=250, size=72)
        n_buckets = 8
        bw, gap = 100, 12
        bx0 = (W - n_buckets * bw - (n_buckets - 1) * gap) // 2
        by0, bh = 900, 300
        for b in range(n_buckets):
            x = bx0 + b * (bw + gap)
            p = prog(t, 0.3 + b * 0.04, 0.3)
            d.rounded_rectangle([x, by0, x + bw, by0 + bh], radius=16, fill=rgba(PANEL, 0.9 * p),
                                outline=rgba(PANEL_EDGE, p), width=2)
            d.text((x + bw / 2, by0 + bh + 34), str(b), font=font("monobold", 30), fill=rgba(MUTED, p),
                   anchor="mm")
        keys = ["HB_NORTH", "LZ_WEST", "HB_SOUTH", "LZ_HOUSTON", "HB_WEST", "LZ_NORTH"]
        buckets = [5, 2, 0, 6, 2, 3]  # fixed demo "hash" values
        fill_count = [0] * n_buckets
        colors = [TEAL, AMBER, PINK, SKY, VIOLET, GREEN]
        for i, (k, b) in enumerate(zip(keys, buckets)):
            st = 0.8 + i * 0.45
            p = prog(t, st, 0.55, ease_in_out)
            if p <= 0:
                continue
            slot = fill_count[b]
            fill_count[b] += 1
            sx, sy = W / 2, 560
            tx = bx0 + b * (bw + gap) + bw / 2
            ty = by0 + bh - 50 - slot * 80
            x, y = lerp(sx, tx, p), lerp(sy, ty, p)
            # label travels as a pill, then shrinks to a dot inside the bucket
            f = font("monobold", 34)
            if p < 1:
                label = f"hash('{k}') → {b}"
                tw = f.getlength(label)
                d.rounded_rectangle([x - tw / 2 - 20, y - 30, x + tw / 2 + 20, y + 30], radius=30,
                                    fill=rgba(PANEL), outline=rgba(colors[i]), width=3)
                d.text((x, y), label, font=f, fill=rgba(colors[i]), anchor="mm")
            else:
                d.ellipse([tx - 30, ty - 30, tx + 30, ty + 30], fill=rgba(colors[i], 0.9))
        if prog(t, 3.6, 0.1) > 0:
            p = prog(t, 3.6, 0.4)
            d.text((bx0 + 2 * (bw + gap) + bw / 2, by0 - 40), "collision", font=font("semibold", 28),
                   fill=rgba(AMBER, p), anchor="mm")
        caption(d, t, "Point lookup = jump straight to *one bucket*", 1300, start=3.4, size=44, color=INK,
                kind="bold", accent=TEAL)

    def sizing(d, t):
        headline(d, t, "Size *BUCKET_COUNT* on purpose", y=250, size=74, accent=AMBER)
        rows = [("bucket_count = 40", "→ 64"), ("bucket_count = 55", "→ 64"), ("bucket_count = 2400", "→ 4096")]
        for i, (a, b) in enumerate(rows):
            p = prog(t, 0.5 + i * 0.4, 0.4)
            y = 560 + i * 130
            d.rounded_rectangle([110, y, W - 110, y + 100], radius=22, fill=rgba(PANEL, 0.95 * p),
                                outline=rgba(PANEL_EDGE, p), width=2)
            d.text((150, y + 50), a, font=font("monobold", 40), fill=rgba(INK, p), anchor="lm")
            pb = prog(t, 0.9 + i * 0.4, 0.4, ease_back)
            d.text((W - 150, y + 50), b, font=font("monobold", 44), fill=rgba(AMBER, min(1, pb)), anchor="rm")
        caption(d, t, "SQL Server rounds up to the *next power of 2*", 980, start=2.0, size=44, color=INK,
                kind="bold")
        caption(d, t, "Rule of thumb: *1–2×* the number of distinct keys.\nToo few buckets = long chains.",
                1110, start=3.0, size=40)

    return Video(
        slug="03_memory_optimized",
        title="Memory-optimized tables in SQL Server",
        part="PART 3/4 · T-SQL",
        scenes=[
            hook_scene(3.4, "SQL SERVER IN-MEMORY OLTP", "This table lives *in RAM.*",
                       "And it's still durable.", accent=TEAL),
            code_scene(5.4, "Step 1: a *memory-optimized* filegroup", step1, title_size=66),
            code_scene(6.6, "Step 2: *MEMORY_OPTIMIZED = ON*", step2, title_size=68,
                       note="Needs a PRIMARY KEY, and only *NONCLUSTERED* indexes", note_start=4.8),
            Scene(5.6, hashing),
            Scene(5.2, sizing),
            code_scene(6.4, "Step 3: *natively compiled* triggers", step3, title_size=68,
                       note="Compiled to machine code: *no interpreter* per row", note_start=4.8),
            outro_scene(3.6, "Built for *real-time price feeds*", "*Dynamic PIVOT* with unknown columns"),
        ],
    )


# ----------------------------------------------------------------------------
# Episode 4: dynamic PIVOT
# ----------------------------------------------------------------------------
def ep_dynamic_pivot() -> Video:
    static = CodePanel(
        code="""
SELECT * FROM
(SELECT HourEnding, RegionID, RegionData
 FROM dbo.LoadModelWeatherForecast) pvt
PIVOT
( MAX([RegionData]) FOR [RegionID]
  IN ([1],[2],[3],[4],[5],[6],[7],[8])
) PvtResult
""",
        title="LMWFtbls.sql  (pivot test)", y=520, type_dur=2.6, highlights=[([5], 3.0, RED)],
    )

    raw = ["HB_NORTH_[HU]", "LZ_WEST_[LZ]", "HB_WEST_[HU]"]
    quoted = ["[HB_NORTH_[HU]]]", "[LZ_WEST_[LZ]]]", "[HB_WEST_[HU]]]"]

    def build(d, t):
        headline(d, t, "Build the column list *from the data*", y=250, size=70)
        stages = [
            (0.4, "SELECT DISTINCT SettlementPointTypeCombo", SKY),
            (1.9, "QUOTENAME( ... )", AMBER),
            (3.5, "',' + ...  FOR XML PATH('')", VIOLET),
            (5.0, "STUFF( ..., 1, 1, '')", RED),
        ]
        cur = 0
        for i, (st, _, _) in enumerate(stages):
            if t >= st:
                cur = i
        st, label, color = stages[cur]
        p = prog(t, st, 0.35)
        f = font("monobold", 34)
        tw = f.getlength(label)
        d.rounded_rectangle([W / 2 - tw / 2 - 26, 470, W / 2 + tw / 2 + 26, 540], radius=35,
                            fill=rgba(color, 0.15 * p), outline=rgba(color, p), width=3)
        d.text((W / 2, 505), label, font=f, fill=rgba(color, p), anchor="mm")

        y0, rh = 640, 120
        q = prog(t, 1.9, 0.5)
        comma = prog(t, 3.5, 0.5, ease_back)
        stuff = prog(t, 5.3, 0.6, ease_in_out)
        for i in range(3):
            y = y0 + i * rh
            pi = prog(t, 0.5 + i * 0.2, 0.35)
            text = quoted[i] if q > 0.5 else raw[i]
            col = lerp(INK, AMBER, q)
            fw = font("monobold", 40)
            text_w = fw.getlength(text)
            x = W / 2 - text_w / 2 + 30
            d.text((x, y), text, font=fw, fill=rgba(col, pi))
            # comma in front of each item
            if comma > 0:
                ca = min(1, comma)
                ccol = VIOLET
                if i == 0 and stuff > 0:
                    ccol = RED
                    ca *= 1 - stuff
                if ca > 0:
                    d.text((x - 50, y - (1 - min(1, comma)) * 30), ",", font=font("monobold", 52),
                           fill=rgba(ccol, ca))
                    if i == 0 and stuff > 0:
                        cross(d, x - 38, y + 26, 22 * (1 - stuff * 0.5), alpha=ca)
        if q > 0.5:
            caption(d, t, "QUOTENAME even escapes the *]* inside the name → *]]*", 1040, start=2.4, size=38)
        result = prog(t, 6.0, 0.5)
        if result > 0:
            caption(d, t, "→ a ready-made *IN ( ... )* list", 1130, start=6.0, size=46, color=INK, kind="bold",
                    accent=TEAL)

    final = CodePanel(
        code="""
SELECT @colSQL = STUFF((SELECT DISTINCT
    ',' + QUOTENAME(SettlementPointTypeCombo)
  FROM dbo.SetPoint_TypeCombo
  FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @pvtSQL = 'SELECT * FROM (...) pivotdata
PIVOT ( MAX([LMP])
  FOR SettlementPointTypeCombo
  IN (' + @colSQL + ')) pivotresult'

EXECUTE (@pvtSQL)
""",
        title="R.L. Mem Opt Triggers.sql", y=470, size=29, type_dur=4.0,
        highlights=[([0, 1, 2, 3, 4], 4.4, AMBER), ([9], 5.2, TEAL), ([11], 5.8, PINK)],
    )

    def pivot_anim(d, t):
        headline(d, t, "Long rows in, *wide grid* out", y=250, size=74)
        long_rows = [
            ("1", "HB_NORTH", "24.10"), ("1", "LZ_WEST", "31.55"), ("1", "HB_WEST", "29.80"),
            ("2", "HB_NORTH", "23.62"), ("2", "LZ_WEST", "30.04"), ("2", "HB_WEST", "28.91"),
        ]
        lc = [120, 260, 170]
        lx0, ly0, rh = 60, 470, 72

        def lbox(r, c):
            x = lx0 + sum(lc[:c]) + 6 * c
            y = ly0 + r * (rh + 6)
            return (x, y, x + lc[c], y + rh)

        for c, h in enumerate(["Int", "Point", "LMP"]):
            cell(d, lbox(0, c), h, fill=(30, 40, 75), text_color=SKY, size=28, kind="bold",
                 alpha=prog(t, 0.2, 0.3))
        # wide grid on the right
        wc = [96, 180, 180, 180]
        wx0 = W - 60 - sum(wc) - 18
        wy0 = 1030

        def wbox(r, c):
            x = wx0 + sum(wc[:c]) + 6 * c
            y = wy0 + r * (rh + 6)
            return (x, y, x + wc[c], y + rh)

        points = ["HB_NORTH", "LZ_WEST", "HB_WEST"]
        ph = prog(t, 1.4, 0.4)
        cell(d, wbox(0, 0), "Int", fill=(48, 34, 80), text_color=VIOLET, size=28, kind="bold", alpha=ph)
        for c, ptn in enumerate(points):
            cell(d, wbox(0, c + 1), ptn, fill=(48, 34, 80), text_color=VIOLET, size=26, kind="bold",
                 alpha=prog(t, 1.4 + c * 0.15, 0.4))
        for r in range(2):
            cell(d, wbox(r + 1, 0), str(r + 1), size=30, kind="mono", alpha=prog(t, 1.9, 0.3))
        for i, (iv, ptn, lmp) in enumerate(long_rows):
            pi = prog(t, 0.3 + i * 0.1, 0.3)
            for c, v in enumerate((iv, ptn, lmp)):
                if c == 2:
                    continue
                cell(d, lbox(i + 1, c), v, size=28, kind="mono", alpha=pi * (1 - 0.5 * prog(t, 2.2 + i * 0.35, 0.5)))
            st = 2.2 + i * 0.35
            p = prog(t, st, 0.6, ease_in_out)
            src = lbox(i + 1, 2)
            dst = wbox(int(iv), points.index(ptn) + 1)
            if t < st:
                cell(d, src, lmp, size=28, kind="mono", alpha=pi, text_color=AMBER)
            else:
                cell(d, lerp(src, dst, p), lmp, size=30, kind="mono", text_color=AMBER,
                     outline=AMBER if p < 1 else PANEL_EDGE)
        caption(d, t, "A new settlement point shows up?\nIt's a *new column* automatically.", 1340, start=4.6,
                size=44, color=INK, kind="bold", accent=GREEN)

    return Video(
        slug="04_dynamic_pivot",
        title="Dynamic PIVOT in SQL Server",
        part="PART 4/4 · T-SQL",
        scenes=[
            hook_scene(3.4, "SQL PIVOT", "PIVOT when you *don't know the columns*", "Let the data write the SQL.",
                       accent=PINK),
            code_scene(5.4, "Static PIVOT = *hard-coded* columns", static, accent=RED, title_size=68,
                       note="New settlement point? *Edit the query. Again.*", note_start=3.4),
            Scene(7.4, build),
            code_scene(7.4, "Glue it into *dynamic SQL*", final, accent=PINK,
                       note="Keep QUOTENAME: it's your guard against *SQL injection*", note_start=6.0),
            Scene(6.2, pivot_anim),
            outro_scene(3.8, "That's the *whole pipeline*", "Comment the SQL topic you want *next*",
                        accent=PINK, label="YOUR TURN", follow="Follow for more SQL from real data jobs"),
        ],
    )


EPISODES = [ep_unpivot, ep_triggers, ep_inmemory, ep_dynamic_pivot]


def _render(builder):
    video = builder()
    path = render(video, OUT_DIR)
    return f"{path}  ({video.duration:.1f}s)"


def main(argv):
    builders = EPISODES
    if argv:
        builders = [b for b in EPISODES if any(a.lower() in b().slug for a in argv)]
    with Pool(min(len(builders), os.cpu_count() or 1)) as pool:
        for line in pool.imap_unordered(_render, builders):
            print("rendered", line)


if __name__ == "__main__":
    main(sys.argv[1:])
