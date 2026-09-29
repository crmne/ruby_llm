# v6 film generator: one world canvas, one virtual camera, one timeline.
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
subprocess.run(["ruby", "-e", 'require "json"; File.write("tools/snippets.json", JSON.pretty_generate(eval(File.read("tools/snippets.rb"))))'], cwd=ROOT, check=True)
S = json.load(open(os.path.join(ROOT, "tools/snippets.json")))
ENGINE = open(os.path.join(ROOT, "src/partials/engine.js")).read()

HTML, JS, CSS = [], [], []


def dims(name):
    lines = S[name].rstrip("\n").split("\n")
    return len(lines), max(len(l) for l in lines)


def code(cid, name, lang, x, y, fs, lh, dark=False, extra_cls="", style=""):
    """Code box in world coordinates. Returns [x, y, w, h] of the text area."""
    n, m = dims(name)
    w = round(m * 0.6 * fs)
    cls = "cb" + (" dark tired-code" if dark else " pending") + (" " + extra_cls if extra_cls else "")
    ign = " data-layout-ignore" if dark else ""
    HTML.append(f'<div class="{cls}" id="{cid}"{ign} data-x="{x}" data-y="{y}" data-fs="{fs}" data-lh="{lh}" data-w="{w}" '
                f'style="left:{x}px;top:{y}px;font-size:{fs}px;line-height:{lh}px;{style}">{{{{code:{lang} {name}}}}}</div>')
    return [x, y, w, n * lh]


def html(s):
    HTML.append(s)


def js(s):
    JS.append(s)


def css(s):
    CSS.append(s)


def region(rid, x, y, w, h, ghost_text, ghost_fs=20, ghost_cols=3):
    """A 'tired' world: dark, dense, desaturated, edge to edge."""
    lines = ghost_text.rstrip("\n").split("\n")
    rows = int(h / (ghost_fs * 1.5)) + 2
    body = "\n".join(lines[i % len(lines)] for i in range(rows))
    col_w = w / ghost_cols
    cols = "".join(f'<pre class="ghost" style="left:{int(c * col_w) + 30}px;font-size:{ghost_fs}px">{body}</pre>' for c in range(ghost_cols))
    html(f'<div class="tired" id="{rid}" data-layout-ignore style="left:{x}px;top:{y}px;width:{w}px;height:{h}px">{cols}<div class="tired-vig"></div></div>')
    return [x, y, w, h]


WARP = [None]


def warp(pairs=None):
    """Map authored times to film times for the JS that follows (piecewise linear, slope 1 outside)."""
    WARP[0] = pairs
    JS.append("warp(%s);" % (json.dumps(pairs) if pairs else "null"))


def W(t):
    pairs = WARP[0]
    if not pairs:
        return t
    if t <= pairs[0][0]:
        return t - pairs[0][0] + pairs[0][1]
    for (a0, n0), (a1, n1) in zip(pairs, pairs[1:]):
        if t <= a1:
            return n0 + (t - a0) * (n1 - n0) / (a1 - a0)
    a, n = pairs[-1]
    return t - a + n


def text_esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build(duration, out="src/index.html", title="RubyLLM v6"):
    page = open(os.path.join(ROOT, "src/partials/shell.html")).read()
    page = page.replace("%%TITLE%%", title).replace("%%DURATION%%", str(duration))
    page = page.replace("%%CSS%%", "\n".join(CSS)).replace("%%WORLD%%", "\n".join(HTML))
    page = page.replace("%%ENGINE%%", ENGINE).replace("%%JS%%", "\n".join(JS))
    open(os.path.join(ROOT, out), "w").write(page)
    print("wrote", out, "duration", duration)


def tired(rid, bid, bname, blang, x, y, fs, lh, ghost, extra_w=900, ghost_fs=22, pad=0.07):
    """Size a 16:9 tired world around a before snippet. Returns dict with rect, center, framing scale."""
    n, m = dims(bname)
    cw, ch = m * 0.6 * fs, n * lh
    w = cw + extra_w
    h = w * 9 / 16
    if h < ch + 260:
        h = ch + 260
        w = h * 16 / 9
    w, h = round(w), round(h)
    px, py = (round(w * pad), round(h * pad))
    region(rid, x - px, y - py, w + 2 * px, h + 2 * py, ghost, ghost_fs=ghost_fs)
    cx0 = x + round(0.06 * w)
    cy0 = y + round((h - ch) / 2)
    code(bid, bname, blang, cx0, cy0, fs, lh, dark=True)
    return {"rect": [x, y, w, h], "c": (x + w / 2, y + h / 2), "s": round(1920 / w, 4), "code": (cx0, cy0, fs, lh)}


def col_of(name, line, needle):
    return S[name].split("\n")[line].index(needle)


def center(box):
    x, y, w, h = box
    return (x + w / 2, y + h / 2)
