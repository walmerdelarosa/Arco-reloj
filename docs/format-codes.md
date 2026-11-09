# Time and date format codes

| Code | Result | Code | Result |
|---|---|---|---|
| `H` / `HH` | hour 0–23 (8 / 08) | `d` / `dd` | day of month (8 / 08) |
| `h` / `hh` | hour 1–12 | `ddd` / `dddd` | Mon / Monday |
| `m` / `mm` | minutes | `M` / `MM` | month (11) |
| `s` / `ss` | seconds | `MMM` / `MMMM` | Nov / November |
| `A` / `a` | AM/PM, am/pm | `yy` / `yyyy` | 26 / 2026 |
| `w` / `ww` | ISO week | `D` / `DDD` | day of the year |
| `Q` | quarter | `'text'` | literal text |
| `\|` | line break | `''` | a single quote |

Example: `dddd, MMMM d | yyyy` → "Sunday, November 8" with "2026" on the next line. Letters that are codes must be quoted to appear as text, e.g. `'week' w`.

Day and month names follow the app language (Settings → App → Language). The same table is shown in Settings → Text → Format codes, next to a live preview.
