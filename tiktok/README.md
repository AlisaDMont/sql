# TikTok series: SQL from a real power-market pipeline

Four vertical (1080×1920, 30 fps, H.264) explainer videos. Each one teaches a technique
used in the `.sql` files in this repository. The finished files are in [`videos/`](videos/),
each with a `_cover.png` to use as the cover image.

| # | File | Length | Teaches | Source in this repo |
|---|------|--------|---------|---------------------|
| 1 | `01_unpivot.mp4` | 30s | UNPIVOT for wide tables → rows, then JOIN to a lookup | `LMWFtbls.sql`, `7 Tables combo .sql` |
| 2 | `02_dedupe_triggers.mp4` | 34s | `DISTINCT` + `NOT EXISTS` in triggers; dead code after `THROW` | `LMWFtbls.sql`, `HourResOutCap.sql` |
| 3 | `03_memory_optimized.mp4` | 36s | Memory-optimized filegroup and tables, HASH indexes and `BUCKET_COUNT`, natively compiled triggers | `R.L. Mem Opt.sql`, `R.L. Mem Opt Triggers.sql` |
| 4 | `04_dynamic_pivot.mp4` | 34s | Dynamic PIVOT with `STUFF` + `QUOTENAME` + `FOR XML PATH` | `R.L. Mem Opt Triggers.sql` |

The videos have a **silent** audio track. Add a sound in the TikTok editor before you post.
Keep the volume low, because the captions carry the content.
All text stays inside TikTok's safe zone, so the app's buttons and caption won't cover it.

## Post captions

**1 · UNPIVOT**
> Your table has one column per region? UNPIVOT turns those columns into rows in one query. Real trigger code from a power-market ETL pipeline. Part 1/4
> `#sql #sqlserver #tsql #dataengineering #etl #learnsql #coding #techtok`

**2 · Duplicate-proof triggers**
> If your trigger inserts duplicates, DISTINCT + NOT EXISTS is the fix. Bonus: why the PRINT after THROW never runs. Part 2/4
> `#sql #sqlserver #tsql #database #dataengineering #learnsql #programming #techtok`

**3 · Memory-optimized tables**
> SQL Server tables that live in RAM and are still durable. Memory-optimized filegroups, HASH indexes, BUCKET_COUNT sizing and natively compiled triggers. Part 3/4
> `#sqlserver #inmemory #tsql #performance #database #dataengineering #techtok`

**4 · Dynamic PIVOT**
> PIVOT when you don't know the column names ahead of time. Build the IN list from the data with STUFF + QUOTENAME. Part 4/4
> `#sql #sqlserver #pivot #tsql #dynamicsql #dataengineering #learnsql #techtok`

## Re-rendering

The videos are generated from code, so you can edit the wording, timing or colours and render them again:

```bash
python3 tiktok/make_videos.py              # all four episodes (about 1 minute on 4 cores)
python3 tiktok/make_videos.py pivot        # only episodes whose slug matches "pivot"
```

Requirements: Python 3 with Pillow, and `ffmpeg` with libx264. Fonts: Inter and JetBrains Mono
(the script falls back to DejaVu if they are missing).

- `engine.py` is the small rendering engine: scenes, easing, rich text, the syntax-highlighted code
  panel with typewriter effect, and the ffmpeg pipe.
- `make_videos.py` defines the four episodes. Each episode is a list of `Scene(duration, draw_fn)`.
