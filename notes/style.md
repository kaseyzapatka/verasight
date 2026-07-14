# Verasight — visualization & write-up style reference

Derived from verasight.io (why-verasight page): **modern, corporate, academic-leaning,
minimal**. Clean sans-serif, generous whitespace, restrained color, high contrast for
readability. The site itself is navy/charcoal + gray on white — understated and trustworthy.

> Exact brand hex codes weren't published on the page; the palette below is a tasteful
> approximation of that navy-and-gray feel, chosen to be colorblind-friendly and to read
> well in print. Swap in official brand hex if provided.

## Palette

| Role | Hex | Use |
|---|---|---|
| Primary (navy) | `#1F2A44` | headlines, axis text, primary bars/lines |
| Accent (teal-blue) | `#2E6E8E` | highlighted series, key value |
| Secondary (slate) | `#6B7683` | secondary series |
| Muted gray | `#B7BEC7` | gridlines, de-emphasized elements |
| Background | `#FFFFFF` | plot + page background |
| Text | `#26303B` | body text |

Sequential ramp (for the Lorenz/density plot): light `#D7E3EA` → `#2E6E8E` → dark `#1F2A44`.

## Typography & layout

- **Sans-serif** throughout (system stack fine: Helvetica/Arial/`sans`).
- Generous whitespace; minimal chartjunk — no heavy borders, light gridlines only.
- Left-aligned titles; concise, sentence-case labels.
- Tables: subtle row separation, bold header row, right-aligned numerics (mirrors the
  case-study example table).

## ggplot defaults (starting point)

- `theme_minimal(base_family = "sans")`, `base_size = 12`.
- Remove minor gridlines; keep light major gridlines only where they aid reading.
- Direct-label or a single clean legend; avoid rainbow palettes — use the palette above.
