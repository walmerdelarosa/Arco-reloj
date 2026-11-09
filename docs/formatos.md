# Códigos de formato de hora y fecha

| Código | Resultado | Código | Resultado |
|---|---|---|---|
| `H` / `HH` | hora 0–23 (8 / 08) | `d` / `dd` | día del mes (8 / 08) |
| `h` / `hh` | hora 1–12 | `ddd` / `dddd` | lun / lunes |
| `m` / `mm` | minutos | `M` / `MM` | mes (11) |
| `s` / `ss` | segundos | `MMM` / `MMMM` | nov / noviembre |
| `A` / `a` | AM/PM, am/pm | `yy` / `yyyy` | 26 / 2026 |
| `w` / `ww` | semana ISO | `D` / `DDD` | día del año |
| `Q` | trimestre | `'texto'` | texto literal |
| `\|` | salto de línea | `''` | una comilla |

Ejemplo: `dddd d 'de' MMMM | yyyy` → «domingo 8 de noviembre» y, debajo, «2026». Las letras que son códigos (como la «d» de «de») deben ir entre comillas simples.


La misma tabla aparece en Ajustes → Texto y formato, junto a una vista previa.
