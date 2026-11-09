.pragma library
// Lógica de tiempo de Arco. Sin dependencias de Qt: se prueba también con Node.

function clamp01(x) { return Math.min(1, Math.max(0, x)); }

function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }

function span(t, start, end) {
    return {
        p: clamp01((t - start) / (end - start)),
        remaining: Math.max(0, end - t),
        total: end - start,
        start: start,
        end: end
    };
}

// opts: { workMode: bool, workStart: horas (p. ej. 8.5), workEnd: horas }
function compute(now, opts) {
    var o = opts || {};
    var y = now.getFullYear(), m = now.getMonth(), d = now.getDate();
    var H = now.getHours(), M = now.getMinutes();
    var t = now.getTime();

    var year = span(t, new Date(y, 0, 1).getTime(), new Date(y + 1, 0, 1).getTime());
    year.segs = 12;

    var month = span(t, new Date(y, m, 1).getTime(), new Date(y, m + 1, 1).getTime());
    month.segs = daysInMonth(y, m);

    var dow = (now.getDay() + 6) % 7;             // lunes = 0
    var week = span(t, new Date(y, m, d - dow).getTime(), new Date(y, m, d - dow + 7).getTime());
    week.segs = 7;

    var day;
    var midnight = new Date(y, m, d).getTime();
    if (o.workMode && o.workEnd > o.workStart) {
        var ws = new Date(y, m, d, 0, Math.round(o.workStart * 60)).getTime();
        var we = new Date(y, m, d, 0, Math.round(o.workEnd * 60)).getTime();
        day = span(t, ws, we);
        day.segs = Math.max(1, Math.round(o.workEnd - o.workStart));
        day.work = true;
        day.before = t < ws;
        day.after = t >= we;
        day.untilStart = Math.max(0, ws - t);
    } else {
        day = span(t, midnight, new Date(y, m, d + 1).getTime());
        day.segs = 24;
        day.work = false;
    }

    var hs = new Date(y, m, d, H).getTime();
    var hour = span(t, hs, hs + 3600000);
    hour.segs = 12;                                // bloques de 5 min

    var ms0 = new Date(y, m, d, H, M).getTime();
    var minute = span(t, ms0, ms0 + 60000);
    minute.segs = 60;                              // un segmento por segundo

    return { year: year, month: month, week: week, day: day, hour: hour, minute: minute };
}

function pad(n) { return n < 10 ? "0" + n : "" + n; }

// Tiempo restante legible. withSeconds=false redondea hacia arriba al minuto.
function fmt(ms, withSeconds) {
    if (!withSeconds && ms > 0) ms = Math.ceil(ms / 60000) * 60000;
    var s = Math.floor(ms / 1000);
    var d = Math.floor(s / 86400); s -= d * 86400;
    var h = Math.floor(s / 3600);  s -= h * 3600;
    var mi = Math.floor(s / 60);   s -= mi * 60;
    if (d > 0) return d + " d " + h + " h";
    if (h > 0) return h + " h " + pad(mi) + " min";
    if (mi > 0) return withSeconds ? mi + " min " + pad(s) + " s" : mi + " min";
    return s + " s";
}

function timeText(now, withSeconds, h12) {
    var H = now.getHours(), M = now.getMinutes(), S = now.getSeconds();
    var hh = h12 ? ((H + 11) % 12 + 1) : pad(H);
    return hh + ":" + pad(M) + (withSeconds ? ":" + pad(S) : "");
}

function daySubtitle(day, withSeconds) {
    if (day.work) {
        if (day.before) return "jornada en " + fmt(day.untilStart, withSeconds);
        if (day.after) return "jornada terminada";
        return "quedan " + fmt(day.remaining, withSeconds) + " de jornada";
    }
    return "quedan " + fmt(day.remaining, withSeconds) + " del día";
}

// Milisegundos hasta el próximo refresco necesario (alineado al segundo o minuto).
function nextDelay(now, needSeconds, smooth) {
    if (smooth) return 33;                         // ~30 fps solo si se pide
    var ms = now.getMilliseconds();
    if (needSeconds) return 1000 - ms + 8;
    return 60000 - (now.getSeconds() * 1000 + ms) + 8;
}

// Desplazamiento anti burn-in: recorre un disco de radio r con ángulo áureo,
// de modo que nunca repite posición en ciclos cortos y cubre el área de forma uniforme.
function burnOffset(k, r) {
    if (r <= 0) return { x: 0, y: 0 };
    var golden = 2.399963229728653;
    var f = Math.sqrt(((k * 0.6180339887) % 1 + 1) % 1);
    return { x: r * f * Math.cos(k * golden), y: r * f * Math.sin(k * golden) };
}

// ---------- Formatos de hora y fecha con códigos ----------
var dayNames = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
var dayShort = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
var monthNames = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
var monthShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

// Semana ISO 8601 (la semana 1 contiene el primer jueves del año).
function isoWeek(now) {
    var d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var dow = (d.getDay() + 6) % 7;
    d.setDate(d.getDate() - dow + 3);                       // jueves de esta semana
    var firstThu = new Date(d.getFullYear(), 0, 4);
    var fdow = (firstThu.getDay() + 6) % 7;
    firstThu.setDate(firstThu.getDate() - fdow + 3);
    return 1 + Math.round((d - firstThu) / 604800000);
}

function dayOfYear(now) {
    var a = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
    return Math.round((a - Date.UTC(now.getFullYear(), 0, 1)) / 86400000) + 1;
}

function token(now, c, n) {
    var H = now.getHours();
    switch (c) {
    case "H": return n >= 2 ? pad(H) : "" + H;
    case "h": var h = (H + 11) % 12 + 1; return n >= 2 ? pad(h) : "" + h;
    case "m": return n >= 2 ? pad(now.getMinutes()) : "" + now.getMinutes();
    case "s": return n >= 2 ? pad(now.getSeconds()) : "" + now.getSeconds();
    case "A": return H < 12 ? "AM" : "PM";
    case "a": return H < 12 ? "am" : "pm";
    case "d":
        if (n === 1) return "" + now.getDate();
        if (n === 2) return pad(now.getDate());
        if (n === 3) return dayShort[now.getDay()];
        return dayNames[now.getDay()];
    case "M":
        if (n === 1) return "" + (now.getMonth() + 1);
        if (n === 2) return pad(now.getMonth() + 1);
        if (n === 3) return monthShort[now.getMonth()];
        return monthNames[now.getMonth()];
    case "y": return n <= 2 ? pad(now.getFullYear() % 100) : "" + now.getFullYear();
    case "w": return n >= 2 ? pad(isoWeek(now)) : "" + isoWeek(now);
    case "D": var j = dayOfYear(now); return n >= 3 ? ("00" + j).slice(-3) : "" + j;
    case "Q": return "" + (Math.floor(now.getMonth() / 3) + 1);
    }
    return null;
}

var TOKENS = "HhmsAadMywDQ";

// Formatea según códigos (H h m s A a d M y w D Q). 'texto' es literal, '' es una comilla
// y | es un salto de línea.
function formatDate(now, fmt) {
    var out = "", i = 0, s = fmt || "";
    while (i < s.length) {
        var c = s.charAt(i);
        if (c === "'") {
            if (s.charAt(i + 1) === "'") { out += "'"; i += 2; continue; }
            i++;
            while (i < s.length) {                         // dentro del literal, '' es una comilla
                if (s.charAt(i) === "'") {
                    if (s.charAt(i + 1) === "'") { out += "'"; i += 2; continue; }
                    i++;
                    break;
                }
                out += s.charAt(i++);
            }
            continue;
        }
        if (c === "|") { out += "\n"; i++; continue; }
        if (TOKENS.indexOf(c) < 0) { out += c; i++; continue; }
        var k = i;
        while (k < s.length && s.charAt(k) === c) k++;
        out += token(now, c, k - i);
        i = k;
    }
    return out;
}

// ¿El formato muestra segundos? (para saber si hay que refrescar cada segundo)
function usesSeconds(fmt) {
    return /s/.test((fmt || "").replace(/'[^']*'?/g, ""));
}

// Hora escrita a mano -> minutos desde las 00:00, o -1 si no es válida.
// Acepta "8", "08", "8:15", "8.15", "8h15", "815", "0815" y "24:00".
function parseHM(text) {
    var t = ("" + text).trim();
    var m = /^(\d{1,2})(?:\s*[:.hH]\s*(\d{1,2})?)?$/.exec(t);
    var H, M;
    if (m) { H = parseInt(m[1], 10); M = m[2] ? parseInt(m[2], 10) : 0; }
    else if (/^\d{3,4}$/.test(t)) { H = parseInt(t.slice(0, t.length - 2), 10); M = parseInt(t.slice(-2), 10); }
    else return -1;
    if (M > 59 || H > 24 || (H === 24 && M > 0)) return -1;
    return H * 60 + M;
}

function fmtHM(minutes) {
    var v = Math.max(0, Math.min(1440, Math.round(minutes)));
    return pad(Math.floor(v / 60)) + ":" + pad(v % 60);
}

var palettes = [
    { name: "Aurora",      c: ["#8B5CF6", "#3B82F6", "#06B6D4", "#10B981", "#F59E0B", "#EF4444"] },
    { name: "Atardecer",   c: ["#BE185D", "#F43F5E", "#FB7185", "#F97316", "#FBBF24", "#FEF3C7"] },
    { name: "Océano",      c: ["#1D4ED8", "#0EA5E9", "#22D3EE", "#2DD4BF", "#5EEAD4", "#E0F2FE"] },
    { name: "Pastel",      c: ["#C4B5FD", "#93C5FD", "#A5F3FC", "#A7F3D0", "#FDE68A", "#FECACA"] },
    { name: "Monocromo",   c: ["#8A8A8A", "#A3A3A3", "#BDBDBD", "#D4D4D4", "#E5E5E5", "#FFFFFF"] },
    { name: "OLED tenue",  c: ["#5B3FA8", "#2F5BA8", "#1F7F8C", "#1F7A55", "#9A6A10", "#9A2E2E"] }
];

var styles = ["Anillos", "Segmentos", "Fino", "Neón", "Bloque",
              "Barras horizontales", "Barras verticales", "Analógico"];

var timePresets = ["HH:mm", "HH:mm:ss", "h:mm A", "h:mm:ss a", "HH'h'mm"];
var datePresets = ["dddd d 'de' MMMM", "ddd d MMM yyyy", "dd/MM/yyyy", "d MMM | 'semana' w",
                   "MMMM yyyy", "'día' DDD 'de' yyyy"];
