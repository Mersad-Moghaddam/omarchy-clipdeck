.pragma library

// DeckTheme: pure color, markup, and formatting helpers for ClipDeck.
//
// Everything here is theme-driven: callers pass live Omarchy palette values
// (Color.menu.*, Color.accent, Style tokens) and receive ready-to-render hex
// strings back. No palette value is ever hardcoded in the QML, and every
// derived color is mixed from the user's own tokens.
//
// The library is deliberately free of Qt globals so it stays trivially
// testable and usable from any QML context.

// ---------------------------------------------------------------------------
// Color math
// ---------------------------------------------------------------------------

// channels() normalizes a QML color object (r/g/b in 0..1) or a "#rgb" /
// "#rrggbb" string into 0..255 components.
function channels(c) {
  if (c === undefined || c === null) return null
  if (typeof c === "object" && c.r !== undefined) {
    return {
      r: Math.round(c.r * 255),
      g: Math.round(c.g * 255),
      b: Math.round(c.b * 255)
    }
  }
  var s = String(c).trim()
  var m = s.match(/^#([0-9a-fA-F]{3})$/)
  if (m) {
    return {
      r: parseInt(m[1].charAt(0) + m[1].charAt(0), 16),
      g: parseInt(m[1].charAt(1) + m[1].charAt(1), 16),
      b: parseInt(m[1].charAt(2) + m[1].charAt(2), 16)
    }
  }
  m = s.match(/^#([0-9a-fA-F]{6})/)
  if (m) {
    return {
      r: parseInt(m[1].substring(0, 2), 16),
      g: parseInt(m[1].substring(2, 4), 16),
      b: parseInt(m[1].substring(4, 6), 16)
    }
  }
  return null
}

function pad(v) {
  var n = Math.max(0, Math.min(255, Math.round(v)))
  var h = n.toString(16)
  return h.length === 1 ? "0" + h : h
}

// hex() renders a color object or string as "#rrggbb" — always opaque, so
// rich-text attributes never depend on Qt's alpha-first string quirk.
function hex(c) {
  var ch = channels(c)
  if (!ch) return "#000000"
  return "#" + pad(ch.r) + pad(ch.g) + pad(ch.b)
}

// mix(a, b, t) blends two colors; t = 0 returns a, t = 1 returns b.
function mix(a, b, t) {
  var ca = channels(a)
  var cb = channels(b)
  if (!ca) return hex(b)
  if (!cb) return hex(a)
  var k = Math.max(0, Math.min(1, t))
  return "#"
    + pad(ca.r + (cb.r - ca.r) * k)
    + pad(ca.g + (cb.g - ca.g) * k)
    + pad(ca.b + (cb.b - ca.b) * k)
}

// luminance() is perceptual (0..1), good enough to pick readable foregrounds.
function luminance(c) {
  var ch = channels(c)
  if (!ch) return 0.5
  return (0.2126 * ch.r + 0.7152 * ch.g + 0.0722 * ch.b) / 255
}

// onFill() returns a readable text color for content drawn on `fill`,
// preserving the fill's hue instead of snapping to pure black or white.
function onFill(fill) {
  if (luminance(fill) > 0.55) return mix(fill, "#000000", 0.86)
  return mix(fill, "#ffffff", 0.93)
}

// ---------------------------------------------------------------------------
// Syntax markup → QML rich text
// ---------------------------------------------------------------------------

// syntaxPalette() builds the token palette from live theme tokens:
//   { fg, accent, muted, bg } → every syntax tone is a mix of those four.
// Nothing here invents hues, so highlighted code always sits inside the
// active theme.
function syntaxPalette(fg, accent, muted, bg) {
  return {
    fg: hex(fg),
    keyword: hex(accent),
    key: hex(mix(accent, fg, 0.25)),
    string: hex(mix(accent, fg, 0.5)),
    number: hex(mix(accent, fg, 0.15)),
    punct: hex(mix(fg, bg, 0.35)),
    comment: hex(mix(muted, bg, 0.15)),
    ln: hex(mix(fg, bg, 0.6))
  }
}

function classColor(cls, pal) {
  if (!pal || !cls || cls.indexOf("t-") !== 0) return ""
  if (cls === "t-ln") return pal.ln
  var name = cls.substring(2)
  if (name.indexOf("comment") === 0) return pal.comment
  if (name.indexOf("json-key") === 0) return pal.key
  if (name.indexOf("keyword") === 0) return pal.keyword
  if (name.indexOf("json-string") === 0
      || name.indexOf("literalstring") === 0
      || name.indexOf("string") === 0) return pal.string
  if (name.indexOf("number") === 0
      || name.indexOf("literalnumber") === 0
      || name.indexOf("json-number") === 0) return pal.number
  if (name.indexOf("json-literal") === 0 || name.indexOf("literal") === 0) return pal.keyword
  if (name.indexOf("operator") === 0
      || name.indexOf("punctuation") === 0
      || name.indexOf("json-punct") === 0) return pal.punct
  return pal.fg
}

var _markupCache = {}
var _markupCacheOrder = []

// markup() converts the daemon's class-based markup into rich text the Qt
// rich-text engine can render with theme colors. It returns "" when the
// markup predates the class format (v0.1.0 inline palette) so callers fall
// back to the strict plain-text viewer instead of showing stale colors.
function markup(src, pal) {
  if (!src || !pal) return ""
  if (String(src).indexOf('class="t-') === -1) return ""

  var key = src.length + ":" + src.slice(0, 32) + ":" + (pal.accent || "") + ":" + (pal.comment || "")
  if (_markupCache[key]) {
    return _markupCache[key]
  }

  var raw = String(src)
  // Cap at 90 lines so Qt RichText layout stays under 16ms even on huge clips
  var lines = raw.split("<br/>")
  if (lines.length > 90) {
    raw = lines.slice(0, 90).join("<br/>") + "<br/><span class=\"t-comment\">&middot;&middot;&middot; (" + (lines.length - 90) + " more lines not shown in preview)</span>"
  }

  var out = raw
  // Strip any defensive leftovers: a v0.1.0 payload or a future change must
  // never smuggle inline styles into the themed surface.
  out = out.replace(/ style="[^"]*"/g, "")
  out = out.replace(/<pre[^>]*>/g, "").replace(/<\/pre>/g, "")
  out = out.replace(/class="([a-z0-9-]+)"/g, function (match, cls) {
    var color = classColor(cls, pal)
    return color ? 'style="color:' + color + '"' : ""
  })

  if (_markupCacheOrder.length >= 32) {
    delete _markupCache[_markupCacheOrder.shift()]
  }
  _markupCacheOrder.push(key)
  _markupCache[key] = out
  return out
}

// ---------------------------------------------------------------------------
// Color value parsing (inspector swatch)
// ---------------------------------------------------------------------------

function hslOf(r, g, b) {
  var rn = r / 255, gn = g / 255, bn = b / 255
  var max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn)
  var h = 0, s = 0, l = (max + min) / 2
  var d = max - min
  if (d !== 0) {
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    if (max === rn) h = (gn - bn) / d + (gn < bn ? 6 : 0)
    else if (max === gn) h = (bn - rn) / d + 2
    else h = (rn - gn) / d + 4
    h /= 6
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) }
}

// parseColorValue() accepts the color formats the daemon detects and returns
// ready-to-display/copy representations.
function parseColorValue(text) {
  var s = String(text || "").trim()
  var r = -1, g = -1, b = -1, a = 1

  var m = s.match(/^#([0-9a-fA-F]{3})$/)
  if (m) {
    r = parseInt(m[1].charAt(0) + m[1].charAt(0), 16)
    g = parseInt(m[1].charAt(1) + m[1].charAt(1), 16)
    b = parseInt(m[1].charAt(2) + m[1].charAt(2), 16)
  } else if ((m = s.match(/^#([0-9a-fA-F]{4})$/))) {
    r = parseInt(m[1].charAt(0) + m[1].charAt(0), 16)
    g = parseInt(m[1].charAt(1) + m[1].charAt(1), 16)
    b = parseInt(m[1].charAt(2) + m[1].charAt(2), 16)
    a = parseInt(m[1].charAt(3) + m[1].charAt(3), 16) / 255
  } else if ((m = s.match(/^#([0-9a-fA-F]{6})$/))) {
    r = parseInt(m[1].substring(0, 2), 16)
    g = parseInt(m[1].substring(2, 4), 16)
    b = parseInt(m[1].substring(4, 6), 16)
  } else if ((m = s.match(/^#([0-9a-fA-F]{8})$/))) {
    r = parseInt(m[1].substring(0, 2), 16)
    g = parseInt(m[1].substring(2, 4), 16)
    b = parseInt(m[1].substring(4, 6), 16)
    a = parseInt(m[1].substring(6, 8), 16) / 255
  } else if ((m = s.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([0-9.]+))?\s*\)$/i))) {
    r = parseInt(m[1], 10); g = parseInt(m[2], 10); b = parseInt(m[3], 10)
    if (m[4] !== undefined) a = parseFloat(m[4])
  } else if ((m = s.match(/^hsla?\(\s*(\d+)\s*,\s*(\d+)%\s*,\s*(\d+)%(?:\s*,\s*([0-9.]+))?\s*\)$/i))) {
    var hsl = { h: parseInt(m[1], 10) / 360, s: parseInt(m[2], 10) / 100, l: parseInt(m[3], 10) / 100 }
    var rgb = rgbFromHsl(hsl.h, hsl.s, hsl.l)
    r = rgb.r; g = rgb.g; b = rgb.b
    if (m[4] !== undefined) a = parseFloat(m[4])
  } else {
    return { ok: false }
  }

  if (r < 0 || g < 0 || b < 0) return { ok: false }
  var hslOut = hslOf(r, g, b)
  var alphaText = a < 1 ? ("a " + Math.round(a * 100) + "%") : ""
  return {
    ok: true,
    hex: "#" + pad(r) + pad(g) + pad(b),
    rgbText: "rgb(" + r + ", " + g + ", " + b + ")",
    hslText: "hsl(" + hslOut.h + ", " + hslOut.s + "%, " + hslOut.l + "%)",
    alphaText: alphaText,
    readable: luminance({ r: r, g: g, b: b }) > 0.55 ? "#000000" : "#ffffff"
  }
}

function rgbFromHsl(h, s, l) {
  h = ((h % 1) + 1) % 1
  if (s === 0) {
    var v = Math.round(l * 255)
    return { r: v, g: v, b: v }
  }
  var q = l < 0.5 ? l * (1 + s) : l + s - l * s
  var p = 2 * l - q
  return {
    r: Math.round(hueToRgb(p, q, h + 1 / 3) * 255),
    g: Math.round(hueToRgb(p, q, h) * 255),
    b: Math.round(hueToRgb(p, q, h - 1 / 3) * 255)
  }
}

function hueToRgb(p, q, t) {
  t = ((t % 1) + 1) % 1
  if (t < 1 / 6) return p + (q - p) * 6 * t
  if (t < 1 / 2) return q
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
  return p
}

// ---------------------------------------------------------------------------
// Text, time, and size formatting
// ---------------------------------------------------------------------------

function isRTL(s) {
  if (!s) return false
  return /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/.test(String(s).substring(0, 400))
}

function lineCount(s) {
  if (!s) return 0
  return String(s).split("\n").length
}

function wordCount(s) {
  if (!s) return 0
  var t = String(s).trim()
  return t === "" ? 0 : t.split(/\s+/).length
}

// timeAgo() accepts an ISO timestamp ("2026-10-15T15:41:39+03:30") or epoch
// milliseconds and returns a compact relative label.
function timeAgo(value, nowMs) {
  if (!value) return ""
  var t = typeof value === "number" ? value : Date.parse(value)
  if (!isFinite(t)) return ""
  var now = nowMs || Date.now()
  var sec = Math.max(0, Math.floor((now - t) / 1000))
  if (sec < 45) return "now"
  if (sec < 3600) return Math.round(sec / 60) + "m"
  if (sec < 86400) return Math.round(sec / 3600) + "h"
  if (sec < 86400 * 2) return "yesterday"
  if (sec < 86400 * 7) return Math.round(sec / 86400) + "d"
  var d = new Date(t)
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return months[d.getMonth()] + " " + d.getDate()
}

// stamp() renders an exact local timestamp for the inspector, where "2d"
// alone is not enough: "Wed 15 Oct, 15:41".
function stamp(value) {
  if (!value) return ""
  var t = typeof value === "number" ? value : Date.parse(value)
  if (!isFinite(t)) return ""
  var d = new Date(t)
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  var hh = String(d.getHours()).padStart(2, "0")
  var mm = String(d.getMinutes()).padStart(2, "0")
  return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()] + ", " + hh + ":" + mm
}

// untilLabel() describes a future TTL: "12s", "4m", "expired".
function untilLabel(expiresAtSeconds, nowMs) {
  var exp = Number(expiresAtSeconds) * 1000
  if (!isFinite(exp) || exp <= 0) return ""
  var now = nowMs || Date.now()
  var sec = Math.floor((exp - now) / 1000)
  if (sec <= 0) return "expired"
  if (sec < 60) return sec + "s"
  if (sec < 3600) return Math.ceil(sec / 60) + "m"
  if (sec < 86400) return Math.ceil(sec / 3600) + "h"
  return Math.ceil(sec / 86400) + "d"
}

function bytes(n) {
  var v = Number(n)
  if (!isFinite(v) || v <= 0) return "0 B"
  if (v < 1024) return v + " B"
  if (v < 1024 * 1024) return (v / 1024).toFixed(1) + " KB"
  if (v < 1024 * 1024 * 1024) return (v / (1024 * 1024)).toFixed(1) + " MB"
  return (v / (1024 * 1024 * 1024)).toFixed(2) + " GB"
}

// domainOf() extracts a host from a URL for compact link labels.
function domainOf(url) {
  var m = String(url || "").match(/^https?:\/\/([^\/?#]+)/i)
  return m ? m[1].replace(/^www\./i, "") : ""
}

// imageDims() reads the "[PNG Image 128x128]" style summary the daemon stores
// in preview for image items.
function imageDims(preview) {
  var m = String(preview || "").match(/(\d+)\s*[x×]\s*(\d+)/)
  if (!m) return ""
  return m[1] + " × " + m[2]
}

// tag() returns the compact three-letter badge for a clip type. Plain ASCII:
// the shell's own UI sticks to a minimal glyph set, and a mono font renders
// these identically in every theme (no icon-font coverage gambles).
function tag(type) {
  switch (String(type || "").toLowerCase()) {
    case "color": return "CLR"
    case "code": return "COD"
    case "json": return "JSN"
    case "link": return "LNK"
    case "email": return "EML"
    case "phone": return "TEL"
    case "file":
    case "path": return "PTH"
    case "image": return "IMG"
    case "number": return "NUM"
    default: return "TXT"
  }
}

// typeName() is the human label used in the inspector hero.
function typeName(type) {
  switch (String(type || "").toLowerCase()) {
    case "color": return "Color"
    case "code": return "Code"
    case "json": return "JSON"
    case "link": return "Link"
    case "email": return "Email"
    case "phone": return "Phone"
    case "file":
    case "path": return "Path"
    case "image": return "Image"
    case "number": return "Number"
    default: return "Text"
  }
}

// clip() shortens text for chips and previews. Length is measured in UTF-16
// units, so the cut must never split a surrogate pair (emoji, rare CJK).
function clip(s, max) {
  var t = String(s === undefined || s === null ? "" : s)
  var m = Math.max(1, max || 40)
  if (t.length <= m) return t
  var cut = t.substring(0, m - 1)
  var last = cut.charCodeAt(cut.length - 1)
  var next = t.charCodeAt(cut.length)
  if (last >= 0xD800 && last <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF) {
    cut = cut.substring(0, cut.length - 1)
  }
  return cut + "…"
}
