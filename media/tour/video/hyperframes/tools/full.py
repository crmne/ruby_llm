import sys, os, math, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import film
from film import *
from open_test import opening

def icon(name, color, size=40):
    svg = open(os.path.join(ROOT, f"assets/icons/{name}.svg")).read()
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S).strip()
    svg = svg.replace('width="24"', f'width="{size}"').replace('height="24"', f'height="{size}"').replace('stroke="currentColor"', f'stroke="{color}"')
    return svg.replace('class="lucide', 'style="display:block;flex:none" class="lucide')
FT = {"png": ("file-image", "#427b58"), "jpeg": ("file-image", "#427b58"), "pdf": ("file-text", "#b30000"), "mp4": ("file-video", "#8f3f71"), "txt": ("file-type", "#b57614")}
def fchip(kind, mime):
    n, c = FT[kind]
    return f'<span class="chip2 ic">{icon(n, c)}<span>{mime}</span></span>'

DUR = 152

# ============================================================ OPENING (0-24)
opening(0.0, wide=False)
html('''<div id="battach" style="position:absolute;left:3030px;top:2880px;width:940px;height:70px;display:flex;align-items:center;gap:14px;padding:0 16px;border-radius:14px;border:2px solid var(--line);background:#fff;opacity:0">
  <span class="fchip" id="fc1">ICON_PNG image.png</span><span class="fchip" id="fc2">ICON_PDF report.pdf</span></div>'''.replace("ICON_PNG", icon("file-image", "#427b58", 30)).replace("ICON_PDF", icon("file-text", "#b30000", 30)))
css('''.fchip { display: inline-flex; align-items: center; gap: 12px; height: 50px; padding: 0 16px; border-radius: 12px; border: 2px solid var(--line); background: var(--card); font-family: var(--mono); font-size: 24px; color: var(--text); white-space: nowrap; }
.fchip b { display: flex; align-items: center; justify-content: center; width: 40px; height: 34px; border-radius: 6px; color: #fff; font-family: var(--sans); font-size: 14px; font-weight: 700; }
.fly { position: absolute; opacity: 0; white-space: nowrap; }''')

# ============================================================ FILES (24-33)
F = tired("rF", "bF", "b_files", "ruby", 5200, 3000, 38, 56, """content: [
  { type: :input_text, text: "..." },
  { type: :input_image, detail: :auto, image_url: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..." },
  { type: :input_file, filename: "report.pdf", file_data: "data:application/pdf;base64,JVBERi0xLjcKJeLjz9MK..." }
]
""")
fx, fy, ffs, flh = F["code"]
FX = 5300
AF = code("aF", "a_files", "ruby", FX, 4460, 44, 64)
V1 = code("aF1", "a_files_1", "ruby", FX, 4460, 44, 64)
V2 = code("aF2", "a_files_2", "ruby", FX, 4460, 44, 64)
V3 = code("aF3", "a_files_3", "ruby", FX, 4460, 44, 64)
FW = [AF[2], V1[2], V2[2], V3[2]]
html(f'''<div id="fkinds" style="position:absolute;left:5300px;top:4640px;width:2000px;height:90px">
  <div class="fk" id="fk0"><b>a picture and a PDF</b>{fchip("png", "image/png")}{fchip("pdf", "application/pdf")}</div>
  <div class="fk" id="fk1"><b>a local path</b>{fchip("png", "image/png")}</div>
  <div class="fk" id="fk2"><b>a URL</b>{fchip("jpeg", "image/jpeg")}</div>
  <div class="fk" id="fk3"><b>several files, mixed</b>{fchip("png", "image/png")}{fchip("mp4", "video/mp4")}{fchip("txt", "text/plain")}</div>
</div>''')
css('''.fk { position: absolute; left: 0; top: 0; display: flex; align-items: center; gap: 16px; opacity: 0; }
.fk b { font-family: var(--sans); font-size: 40px; font-weight: 700; color: var(--red); margin-right: 12px; }
.chip2 { display: inline-flex; align-items: center; gap: 12px; font-family: var(--mono); font-size: 30px; color: #076678; padding: 12px 20px; border-radius: 12px; background: var(--card); border: 2px solid var(--line); white-space: nowrap; }
.chip2 i { display: block; width: 14px; height: 14px; border-radius: 50%; }
.chip2.ic { gap: 10px; padding: 8px 18px 8px 12px; }''')
html('<div class="bigtype" id="ho-weather" style="left:5300px;top:4790px;font-size:84px;white-space:nowrap;opacity:0">"What\'s the weather in Berlin?"</div>')
c_img = col_of("b_files", 1, '"image.png"')
c_pdf = col_of("b_files", 2, '"report.pdf"')
fcx, fcy = F["c"]
afc = (FX + FW[0] / 2, 4520)
warp([[0, 2]])
js(f"""
        // ======== FILES ========
        tl.fromTo("#battach", {{ opacity: 0, y: 20 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "expo.out", immediateRender: false }}, 23.3);
        tl.fromTo("#fc1", {{ x: 0, y: 0, scale: 1 }}, {{ x: {fx + c_img * ffs * 0.6} - 3046, y: {fy + flh} - 2890, scale: 0.9, duration: 0.9, ease: "power3.inOut", immediateRender: false }}, 24.1);
        tl.fromTo("#fc2", {{ x: 0, y: 0, scale: 1 }}, {{ x: {fx + c_pdf * ffs * 0.6} - 3230, y: {fy + 2 * flh} - 2890, scale: 0.9, duration: 0.9, ease: "power3.inOut", immediateRender: false }}, 24.2);
        tl.to(["#fc1", "#fc2"], {{ opacity: 0, duration: 0.15 }}, 24.98);
        hbox({fx + c_img * ffs * 0.6}, {fy + flh}, {11 * ffs * 0.6}, {flh}, 25.0, 25.75);
        hbox({fx + c_pdf * ffs * 0.6}, {fy + 2 * flh}, {12 * ffs * 0.6}, {flh}, 25.1, 25.75);
        cam(24.0, 0.9, {{ x: {fcx}, y: {fcy}, s: {F['s']}, r: 0.8, ry: 0 }}, "power3.inOut");
        whipBlur(24.0, 0.9, 6);
        cam(24.9, 1.65, {{ s: {F['s'] * 1.05:.4f}, r: 0.3 }}, "sine.inOut");
        mark("#bF", 1, 2, 25.0, 1.1, "Base64 by hand");
        mark("#bF", 9, 9, 25.5, 0.55, "MIME types in data URLs");
        mark("#bF", 6, 12, 26.1, 0.7, "content part arrays");
        collapseRegion("#rF", {afc[0]}, {afc[1]}, 26.5, 0.5);
        compress("#bF", "#aF", 26.55, "shatter", {{ match: "What's in these files? image.png report.pdf", dur: 0.45, seed: 13, shake: 11, violent: true }});
        cam(27.45, 0.8, {{ x: {afc[0]}, y: 4600, s: 1.01 }}, "power3.inOut");
        swapBox("#aF", "#aF1", 28.6);
        swapBox("#aF1", "#aF2", 30.0);
        swapBox("#aF2", "#aF3", 31.3);
        [["#fk0", 27.3, 28.6], ["#fk1", 28.7, 30.0], ["#fk2", 30.1, 31.3], ["#fk3", 31.4, 32.4]].forEach(([k, a, b]) => {{
          tl.fromTo(k, {{ opacity: 0, y: 20 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "back.out(1.8)", immediateRender: false }}, a);
          tl.to(k, {{ opacity: 0, y: -16, duration: 0.18 }}, b - 0.05);
        }});
        cam(28.45, 0.45, {{ x: {FX + FW[1] / 2}, s: 1.01 }}, "power2.inOut");
        cam(29.85, 0.45, {{ x: {FX + FW[2] / 2}, s: 1.0 }}, "power2.inOut");
        cam(30.3, 0.8, {{ s: 1.01 }}, "sine.inOut");
        cam(31.15, 0.45, {{ x: {FX + FW[3] / 2}, s: 1.0 }}, "power2.inOut");
""")

# ============================================================ TOOLS (33-46)
T = tired("rT", "bT", "b_tools", "ruby", 7600, 3300, 30, 44, """tools = [{ type: :function, name: "get_weather",
  parameters: { type: :object, properties: { latitude: { type: :number } } },
  required: ["latitude", "longitude"], additionalProperties: false, strict: true }]
input.concat(response.output)
{ type: :function_call_output, call_id: call.call_id, output: JSON.generate(result) }
""")
tx, ty, tfs, tlh = T["code"]
AT = code("aT", "a_tools", "ruby", 7700, 4900, 40, 60)
c_w = col_of("b_tools", 9, '"What')
tcx, tcy = T["c"]
html('''<div id="thread" style="position:absolute;left:9260px;top:4880px;width:840px;display:flex;flex-direction:column;gap:22px">
  <div class="qb" id="tq" style="align-self:flex-end">What's the weather in Berlin?</div>
  <div id="tcall" class="tcall"><div class="tch"><i></i>TOOL CALL</div><div class="tcb">weather(latitude: 52.52,<br>        longitude: 13.41)</div></div>
  <div class="chip2" id="tres" style="align-self:flex-start;color:#356b49">{ temperature: 18, wind: 12 }</div>
  <div class="ab" id="tans"><img class="ava" src="assets/logos/logo.svg" alt="" /><div>It's 18°C and breezy in Berlin.</div></div>
</div>''')
css('''#thread > * { opacity: 0; }
#thread .qb, #mthread .qb, #mqfly { font-size: 40px; }
#thread .tcb { font-size: 36px; }
#thread .tch { font-size: 24px; }
#thread .chip2, #mthread .chip2 { font-size: 36px; }
#thread .ab > div, #mthread .ab > div { font-size: 38px; }
.qb { font-family: var(--sans); font-size: 34px; color: #fdf6f4; background: var(--red); padding: 18px 26px; border-radius: 26px 26px 8px 26px; white-space: nowrap; box-shadow: 0 18px 40px rgba(179,0,0,0.2); }
.tcall { border-radius: 18px; background: var(--card); border: 2px solid var(--line); box-shadow: 0 20px 44px rgba(66,42,34,0.1); overflow: hidden; }
.tch { height: 54px; display: flex; align-items: center; gap: 10px; padding: 0 22px; background: var(--bar); border-bottom: 2px solid var(--line); font-family: var(--sans); font-weight: 700; font-size: 20px; letter-spacing: 0.12em; color: var(--soft); }
.tch i { display: block; width: 13px; height: 13px; border-radius: 50%; background: #b57614; }
.tcb { padding: 18px 22px; font-family: var(--mono); font-size: 30px; color: #076678; }
.ab { display: flex; gap: 16px; align-items: flex-start; }
.ab > div { font-family: var(--sans); font-size: 32px; line-height: 1.4; color: var(--text); padding: 18px 24px; border-radius: 8px 24px 24px 24px; background: var(--card); border: 2px solid var(--line); box-shadow: 0 18px 40px rgba(66,42,34,0.08); }''')
warp([[33, 35], [37.0, 39.0], [41.2, 42.2]])
js(f"""
        // ======== TOOLS ========
        tl.fromTo("#ho-weather", {{ opacity: 0, scale: 1.3 }}, {{ opacity: 1, scale: 1, duration: 0.3, ease: "power4.out", immediateRender: false }}, 32.45);
        cam(32.4, 0.5, {{ y: 4800, s: 0.95 }}, "power2.out");
        tl.fromTo("#ho-weather", {{ x: 0, y: 0, scale: 1 }}, {{ x: {tx + c_w * tfs * 0.6} - 5300, y: {ty + 9 * tlh} - 4790 - 8, scale: {tfs / 84:.3f}, transformOrigin: "0% 0%", duration: 0.7, ease: "power3.inOut", immediateRender: false }}, 33.0);
        tl.to("#ho-weather", {{ opacity: 0, duration: 0.15 }}, 33.65);
        hbox({tx + c_w * tfs * 0.6}, {ty + 9 * tlh}, {31 * tfs * 0.6}, {tlh}, 33.65, 35.25);
        cam(33.0, 0.7, {{ x: {tcx}, y: {tcy}, s: {T['s']}, r: -1 }}, "power3.inOut");
        cam(33.6, 2.45, {{ s: {T['s'] * 1.05:.4f}, r: -0.4 }}, "sine.inOut");
        mark("#bT", 0, 7, 33.8, 1.1, "hand-written JSON schema");
        mark("#bT", 10, 13, 34.6, 0.9, "find the call yourself");
        mark("#bT", 14, 15, 35.2, 0.7, "parse and dispatch");
        mark("#bT", 16, 19, 35.6, 0.6, "send results back");
        collapseRegion("#rT", 8420, 5170, 36.0, 0.5);
        compress("#bT", "#aT", 36.05, "fold", {{ match: "What's the weather in Berlin?", dur: 0.45, seed: 17, shake: 9 }});
        // walkthrough: push in on each part, top to bottom
        const steps = [[0, 0, 37.3, 8000, 4930, 1.6], [0, 0, 38.1, 8250, 4930, 1.45], [1, 1, 38.9, 8350, 4990, 1.3], [3, 5, 39.7, 8200, 5140, 1.25], [8, 8, 40.6, 8400, 5300, 1.15]];
        steps.forEach(([a, b, t0, x, y, s]) => {{ cam(t0 - 0.3, 0.45, {{ x: x, y: y, s: s }}, "power3.inOut"); focus("#aT", a, b, t0, 0.65); }});
        const tw = Array.from(document.querySelectorAll('#aT .ln[data-ln="0"] .t'));
        tl.fromTo(tw.filter((x) => x.textContent === "Weather"), {{ scale: 1 }}, {{ scale: 1.3, duration: 0.2, yoyo: true, repeat: 1, immediateRender: false }}, 37.35);
        tl.fromTo(tw.filter((x) => /RubyLLM|</.test(x.textContent)), {{ scale: 1 }}, {{ scale: 1.25, duration: 0.2, yoyo: true, repeat: 1, immediateRender: false }}, 38.15);
        cam(41.2, 0.6, {{ x: 8900, y: 5170, s: 0.72, r: 0.5 }}, "power3.inOut");
        pop("#tq", 41.6, "100% 100%"); pop("#tcall", 42.2, "50% 0%"); pop("#tres", 42.9, "0% 50%"); pop("#tans", 43.5, "0% 0%");
        cam(41.8, 3.4, {{ x: 8900, s: 0.73, r: 0 }}, "sine.inOut");
""")

# ============================================================ MCP (46-59)
M = tired("rM", "bM", "b_mcp", "shell", 11000, 3900, 30, 44, """POST https://mcp.linear.app/mcp
Accept: application/json, text/event-stream
MCP-Protocol-Version: 2026-07-28
{ "jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": { "_meta": { ... } } }
event: message
data: { "jsonrpc": "2.0", "id": 2, "result": { "tools": [ ... ] } }
""")
mx, my, mfs, mlh = M["code"]
AM = code("aM", "a_mcp", "ruby", 11100, 5900, 40, 60)
mcx, mcy = M["c"]
swaps = []
for i, n in enumerate(["m_github", "m_notion", "m_atlassian", "m_sentry"]):
    swaps.append(code(f"sw{i}", n, "ruby", 11100 + i * 2200, 7000, 40, 60))
html('''<div id="mthread" style="position:absolute;left:12540px;top:5880px;width:840px;display:flex;flex-direction:column;gap:20px">
  <div class="qb" id="mq" style="align-self:flex-end">What's blocking the release?</div>
  <div class="chip2" id="mt1" style="align-self:flex-start"><i style="background:#b57614"></i>list_issues</div>
  <div class="chip2" id="mt2" style="align-self:flex-start"><i style="background:#b57614"></i>get_issue</div>
  <div class="ab" id="mans"><img class="ava" src="assets/logos/logo.svg" alt="" /><div>Two open issues block the release: a failing migration and a pending review.</div></div>
</div>
''')
css("#mthread > * { opacity: 0; }")
warp([[0, 1]])
js(f"""
        // ======== MCP ========
        const mqClone = document.createElement("div"); mqClone.className = "qb fly"; mqClone.id = "mqfly"; mqClone.textContent = "What's blocking the release?";
        mqClone.style.left = "9500px"; mqClone.style.top = "5700px"; mqClone.style.position = "absolute"; document.getElementById("world").appendChild(mqClone);
        tl.fromTo("#mqfly", {{ opacity: 0, y: 30 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "back.out(1.8)", immediateRender: false }}, 45.3);
        cam(45.3, 0.4, {{ y: 5400, s: 0.8 }}, "power2.inOut");
        tl.to("#mqfly", {{ x: {mx + 1300} - 9500, y: {my - 70} - 5700, duration: 0.8, ease: "power3.inOut" }}, 46.0);
        cam(46.0, 0.75, {{ x: {mcx}, y: {mcy}, s: {M['s']}, r: 1.2 }}, "power4.inOut");
        whipBlur(46.0, 0.75, 7);
        cam(46.75, 2.3, {{ s: {M['s'] * 1.05:.4f}, r: 0.5 }}, "sine.inOut");
        mark("#bM", 1, 6, 46.8, 1.1, "headers on every POST");
        mark("#bM", 10, 13, 47.6, 0.9, "protocol metadata");
        mark("#bM", 14, 15, 48.3, 0.7, "and all of this");
        collapseRegion("#rM", 11772, 6050, 49.0, 0.5);
        tl.to("#mqfly", {{ x: 13380 - 9500, xPercent: -100, y: 5880 - 5700, duration: 0.6, ease: "power3.inOut" }}, 49.1);
        tl.to("#mqfly", {{ opacity: 0, duration: 0.1 }}, 49.7);
        tl.set("#mq", {{ opacity: 1 }}, 49.7);
        compress("#bM", "#aM", 49.05, "vacuum", {{ match: "https://mcp.linear.app/mcp", dur: 0.45, seed: 23, shake: 9 }});
        cam(49.95, 0.7, {{ x: 12240, y: 6120, s: 0.77 }}, "power3.inOut");
        pop("#mt1", 50.3, "0% 50%"); pop("#mt2", 50.8, "0% 50%"); pop("#mans", 51.5, "0% 0%");
        cam(50.65, 2.75, {{ x: 12250, s: 0.78 }}, "sine.inOut");
        // server swaps: whip along the row
        const SWC = {json.dumps([11100 + i * 2200 + w / 2 for i, (_, _, w, _) in enumerate(swaps)])};
        tl.fromTo("#mnote", {{ opacity: 0, y: 20 }}, {{ opacity: 1, y: 0, duration: 0.35, ease: "expo.out", immediateRender: false }}, 53.85);
        afterIn("#sw0", 53.75, 0.006);
        cam(53.5, 0.5, {{ x: SWC[0], y: 7050, s: 1.0 }}, "power3.inOut");
        [1, 2, 3].forEach((i) => {{
          const t0 = 54.0 + i;
          afterIn("#sw" + i, t0 + 0.25, 0.006);
          cam(t0, 0.45, {{ x: SWC[i], y: 7050 + (i % 2 ? -30 : 30), s: 1.0, r: i % 2 ? 0.8 : -0.8 }}, "power4.inOut");
          whipBlur(t0, 0.45, 6);
        }});
        tl.to("#mnote", {{ opacity: 0, y: -16, duration: 0.25, ease: "power2.in" }}, 58.25);
""")

# ============================================================ STRUCTURED (59-69)
P = tired("rP", "bP", "b_schema", "ruby", 16800, 4300, 34, 50, """product_schema = { type: :object, properties: { name: { type: :string } } }
text: { format: { type: :json_schema, name: "product", strict: true, schema: product_schema } }
product = JSON.parse(response.output_text)
required: %w[name price features], additionalProperties: false
""")
px_, py_, pfs, plh = P["code"]
AP = code("aP", "a_schema", "ruby", 16900, 5900, 36, 54)
PP = code("pp", "a_parsed", "ruby", 18140, 6340, 32, 48)
pcx, pcy = P["c"]
PTX = ["hey!! so this is our ruby mug,", "it's $18, ceramic & holds 12 oz", "oh and its dishwasher safe :)", "ships in 2-3 days, ask re: bulk"]
PICK = [("ruby mug", 0, 1, ['"Ruby', 'Mug",']), ("$18", 1, 2, ["18.0,"]), ("ceramic", 1, 4, ['"Ceramic",']), ("12 oz", 1, 4, ['"12', 'oz",']), ("dishwasher safe", 2, 4, ['"Dishwasher', 'safe"'])]
PBX, PBY, PFS, PLH = 18100 + 40, 5880 + 64 + 28, 32, 48
body = []
for ln in PTX:
    e = text_esc(ln)
    for k, (ph, li, _, _) in enumerate(PICK):
        if PTX[li] == ln:
            e = e.replace(text_esc(ph), f'<span id="pv{k}">{text_esc(ph)}</span>', 1)
    body.append(e)
html(f'''<div class="panel" id="prod" style="left:18100px;top:5880px;width:960px;height:{64 + 28 + 4 * PLH + 30}px;opacity:0"><div class="bar"><i></i><i></i><i></i>product.txt</div>
  <pre id="ptxt" style="position:absolute;left:40px;top:{64 + 28}px;margin:0;font-family:var(--mono);font-size:{PFS}px;line-height:{PLH}px;color:var(--text)">{chr(10).join(body)}</pre></div>
<div class="panel" id="ppcard" style="left:18100px;top:6250px;width:960px;height:450px;opacity:0"><div class="bar"><i></i><i></i><i></i>response.parsed</div></div>''')
css("#ptxt span { border-radius: 6px; }")
pal = S["a_parsed"].split("\n")
picks_js = []
for k, (ph, li, tli, toks) in enumerate(PICK):
    sx = PBX + PTX[li].index(ph) * PFS * 0.6
    sy = PBY + li * PLH
    tx = 18140 + pal[tli].index(toks[0]) * 32 * 0.6
    ty = 6340 + tli * 48
    html(f'<div class="fly pfly" id="pf{k}" style="left:{sx:.0f}px;top:{sy:.0f}px">{text_esc(ph)}</div>')
    picks_js.append([f"#pv{k}", f"#pf{k}", toks, round(tx - sx), round(ty - sy)])
css(".pfly { font-family: var(--mono); font-size: 32px; line-height: 48px; color: #b30000; background: rgba(179,0,0,0.1); border-radius: 6px; }")
css("#ppcard { z-index: 0 } #pp { z-index: 1 }")
warp([[59, 60], [63, 64], [68.2, 70.2]])
js(f"""
        // ======== STRUCTURED OUTPUT ========
        tl.to(["#sw0", "#sw1", "#sw2", "#sw3"], {{ opacity: 0, duration: 0.3 }}, 59.4);
        cam(58.5, 0.9, {{ x: {pcx}, y: {pcy}, s: {P['s']}, r: -1, ry: 10 }}, "power3.inOut");
        whipBlur(58.5, 0.9, 7);
        cam(59.5, 2.55, {{ s: {P['s'] * 1.05:.4f}, r: -0.3, ry: 4 }}, "sine.inOut");
        mark("#bP", 0, 9, 59.7, 1.1, "schema as nested hashes");
        mark("#bP", 13, 14, 60.5, 0.8, "format options");
        mark("#bP", 16, 16, 61.2, 0.7, "parse it yourself");
        collapseRegion("#rP", 17800, 6180, 62.0, 0.5);
        compress("#bP", "#aP", 62.05, "shatter", {{ match: "name price features", dur: 0.45, seed: 29, shake: 9 }});
        cam(62.95, 0.7, {{ x: 17980, y: 6290, s: 0.8 }}, "power3.inOut");
        tl.fromTo("#prod", {{ opacity: 0, x: 120 }}, {{ opacity: 1, x: 0, duration: 0.45, ease: "expo.out", immediateRender: false }}, 63.1);
        tl.fromTo("#ppcard", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.4, ease: "expo.out", immediateRender: false }}, 63.8);
        cam(63.65, 4.45, {{ x: 17990, s: 0.82 }}, "sine.inOut");
        const pl = Array.from(document.querySelectorAll("#pp .t"));
        const vals = new Set(['"Ruby', 'Mug",', "18.0,", '"Ceramic",', '"12', 'oz",', '"Dishwasher', 'safe"']);
        tl.fromTo(pl.filter((x) => !vals.has(x.textContent)), {{ opacity: 0 }}, {{ opacity: 1, duration: 0.2, stagger: 0.01, immediateRender: false }}, 64.0);
        {json.dumps(picks_js)}.forEach(([src, fly, toks, dx, dy], k) => {{
          const t0 = 64.5 + k * 0.5;
          tl.fromTo(src, {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.14)", duration: 0.2, immediateRender: false }}, t0 - 0.15);
          tl.fromTo(fly, {{ opacity: 0, x: 0, y: 0 }}, {{ opacity: 1, duration: 0.1, immediateRender: false }}, t0);
          tl.to(fly, {{ x: dx, y: dy, duration: 0.5, ease: "power3.inOut" }}, t0 + 0.05);
          tl.to(fly, {{ opacity: 0, duration: 0.15 }}, t0 + 0.55);
          toks.forEach((tx) => {{ const tok = pl.find((x) => x.textContent === tx); if (tok) tl.fromTo(tok, {{ opacity: 0 }}, {{ opacity: 1, duration: 0.15, immediateRender: false }}, t0 + 0.5); }});
        }});
""")

# ============================================================ JUDGE (69-76)
JX, JY = 19700, 7000
TKX, TKY = 18100, 5760
AJ = code("aJ", "a_judge", "ruby", JX, JY, 34, 52)
html(f'''<div class="qb" id="ticket" style="position:absolute;left:{TKX}px;top:{TKY}px;opacity:0">Charged twice for my Ruby Mug. Refund me today!</div>
<div id="jres" style="position:absolute;left:{JX}px;top:{JY + 538}px;width:1632px;display:flex;flex-direction:row;align-items:center;gap:90px">
  <div class="jrow" id="jr1"><span>urgent.probability</span><div class="jbar"><i id="jb1"></i></div><b>0.97</b></div>
  <div class="jdist" id="jr2"><div class="jlab">frustration.probabilities</div>
    <div class="jcol"><u><i style="height:50px"></i></u><span>Calm</span></div><div class="jcol"><u><i style="height:190px;background:#b30000"></i></u><span>Frustrated</span></div><div class="jcol"><u><i style="height:120px"></i></u><span>Angry</span></div></div>
</div>''')
css('''#jres > * { opacity: 0; }
.jrow { flex: 1; display: flex; align-items: center; gap: 22px; font-family: var(--mono); font-size: 34px; }
.jrow b { font-family: var(--sans); font-size: 56px; color: var(--red); }
.jdist { width: 760px; flex: none; }
.jbar { flex: 1; height: 26px; border-radius: 13px; background: #efe7e2; overflow: hidden; }
.jbar { position: relative; } .jbar i { display: block; height: 100%; width: 97%; border-radius: 13px; background: #b30000; }
.jdist { display: flex; align-items: flex-end; gap: 24px; height: 300px; position: relative; padding-top: 50px; }
.jlab { position: absolute; left: 0; top: 0; font-family: var(--mono); font-size: 34px; }
.jcol { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; height: 100%; gap: 12px; }
.jcol u { display: flex; align-items: flex-end; width: 100%; height: 190px; overflow: hidden; } .jcol i { display: block; width: 100%; border-radius: 12px 12px 4px 4px; background: #d8ccc5; }
.jcol span { font-family: var(--sans); font-size: 30px; color: var(--muted); }''')
warp([[0, 2]])
js(f"""
        // ======== JUDGE ========
        tl.fromTo("#ticket", {{ opacity: 0, scale: 0.6 }}, {{ opacity: 1, scale: 1, duration: 0.35, ease: "back.out(2)", immediateRender: false }}, 68.5);
        tl.to("#prod", {{ opacity: 0.25, duration: 0.3 }}, 68.5);
        cam(68.5, 0.45, {{ x: 18500, y: 6000, s: 0.86, r: 1 }}, "power3.out");
        cam(69.0, 0.9, {{ x: {JX + 816}, y: {JY + 359}, s: 0.94, r: 0, ry: 0 }}, "power4.inOut");
        whipBlur(69.0, 0.9, 5);
        tl.to("#ticket", {{ x: {JX - TKX}, y: {JY - 130 - TKY}, transformOrigin: "0% 0%", duration: 0.9, ease: "power4.inOut" }}, 69.0);
        afterIn("#aJ", 69.4, 0.005);
        cam(69.9, 5.8, {{ s: 0.93 }}, "sine.inOut");
        // what judges it, what it asks, how sure it is
        tl.fromTo('#aJ .ln[data-ln="1"]', {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.1)", duration: 0.25, immediateRender: false }}, 70.6);
        tl.to('#aJ .ln[data-ln="1"]', {{ backgroundColor: "rgba(179,0,0,0)", duration: 0.25 }}, 71.3);
        tl.fromTo('#aJ .ln[data-ln="2"]', {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.1)", duration: 0.25, immediateRender: false }}, 71.3);
        tl.fromTo("#jr1", {{ opacity: 0, y: 16 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "power2.out", immediateRender: false }}, 72.0);
        tl.set("#jb1", {{ xPercent: -100 }}, 0);
        tl.set("#jr2 .jcol i", {{ yPercent: 100 }}, 0);
        tl.fromTo("#jb1", {{ xPercent: -100 }}, {{ xPercent: 0, duration: 0.7, ease: "power3.out", immediateRender: false }}, 72.1);
        tl.to('#aJ .ln[data-ln="2"]', {{ backgroundColor: "rgba(179,0,0,0)", duration: 0.25 }}, 72.9);
        tl.fromTo('#aJ .ln[data-ln="3"], #aJ .ln[data-ln="4"]', {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.1)", duration: 0.25, immediateRender: false }}, 72.9);
        tl.fromTo("#jr2", {{ opacity: 0, y: 16 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "power2.out", immediateRender: false }}, 73.0);
        tl.fromTo("#jr2 .jcol i", {{ yPercent: 100 }}, {{ yPercent: 0, duration: 0.55, ease: "power3.out", stagger: 0.1, immediateRender: false }}, 73.1);
""")

# ============================================================ AGENT (76-86)
AL = code("aL", "a_refund", "ruby", 23300, 6800, 34, 50)
AR = code("aR", "a_refund_run", "ruby", AL[0] + AL[2] + 44 + 240 + 44, 6800, 32, 48)
ALC = (AL[0] - 44 + (AL[2] + 88) / 2, AL[1] - 100 + (AL[3] + 136) / 2)
ARC = (AR[0] - 44 + (AR[2] + 88) / 2, AR[1] - 100 + (AR[3] + 136) / 2)
APB = AR[1] + AR[3] + 80 + 300
AGW = (AL[0] - 44, AR[0] + AR[2] + 44, AL[1] - 100, max(APB, AL[1] + AL[3] + 190))
ar = AR
html(f'''<div class="panel" id="alcard" style="left:{AL[0]-44}px;top:{AL[1]-100}px;width:{AL[2]+88}px;height:{AL[3]+136}px;opacity:0"><div class="bar"><i></i><i></i><i></i>app/agents/support_agent.rb</div></div>
<div class="panel" id="arcard" style="left:{AR[0]-44}px;top:{AR[1]-100}px;width:{AR[2]+88}px;height:{AR[3]+136}px;opacity:0"><div class="bar"><i></i><i></i><i></i>app/jobs/billing_job.rb</div></div>
<div id="appr" style="position:absolute;left:{AR[0]-44}px;top:{AR[1]+AR[3]+80}px;width:{AR[2]+88}px;padding:28px 32px;border-radius:20px;background:#fffdfb;border:2px solid var(--line);box-shadow:0 26px 60px rgba(66,42,34,0.12);opacity:0">
  <div style="display:flex;justify-content:space-between"><div id="ast" style="font-family:var(--sans);font-weight:700;font-size:24px;letter-spacing:0.14em;color:#8a5a0f">APPROVAL NEEDED</div><div id="aok" style="font-family:var(--sans);font-weight:700;font-size:24px;letter-spacing:0.14em;color:#356b49;opacity:0">APPROVED</div></div>
  <div style="font-family:var(--sans);font-size:34px;color:var(--text);margin:14px 0 6px">SupportAgent wants to run</div>
  <div style="font-family:var(--mono);font-size:32px;color:#076678">issue_refund(order_id: 42)</div>
  <div style="display:flex;gap:18px;justify-content:flex-end;margin-top:22px"><span style="padding:14px 30px;border-radius:12px;border:2px solid var(--line);font-family:var(--sans);font-weight:600;font-size:30px;color:var(--muted)">Deny</span><span id="abtn" style="padding:14px 30px;border-radius:12px;background:#356b49;font-family:var(--sans);font-weight:600;font-size:30px;color:#fff">Approve</span></div>
</div>
<div class="ab" id="adone" style="position:absolute;left:{AL[0]}px;top:{AL[1]+AL[3]+60}px;opacity:0"><img class="ava" src="assets/logos/logo.svg" alt="" /><div style="white-space:nowrap">Refund issued for order 42.</div></div>
<svg id="cursor" width="56" height="56" viewBox="0 0 24 24" style="position:absolute;left:{AR[0]+AR[2]-40}px;top:{AR[1]+AR[3]+520}px;opacity:0"><path d="M4 2 L4 20 L9 15 L12.5 22 L15.5 20.5 L12 13.5 L19 13.5 Z" fill="#2c2926" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>''')
css("#alcard, #arcard { z-index: 0 } #aL, #aR { z-index: 1 }")
btn_x = AR[0] + AR[2] + 44 - 32 - 90
btn_y = AR[1] + AR[3] + 80 + 28 + 34 + 60 + 50 + 22 + 30
warp([[0, 2]])
js(f"""
        // ======== AGENT ========
        tl.to(["#aJ", "#jres"], {{ opacity: 0, duration: 0.3 }}, 76.0);
        tl.to("#ticket", {{ x: {AR[0] + 400 - TKX}, y: {AR[1] + 48 * 2 - TKY - 30}, scale: 0.6, duration: 0.8, ease: "power3.inOut" }}, 76.0);
        tl.to("#ticket", {{ opacity: 0, duration: 0.2 }}, 76.8);
        cam(76.0, 0.9, {{ x: {(AGW[0] + AGW[1]) / 2}, y: {(AGW[2] + AGW[3]) / 2}, s: {round(1920 / (AGW[1] - AGW[0] + 160), 4)}, ry: 0, r: -1 }}, "power4.inOut");
        whipBlur(76.0, 0.9, 6);
        tl.fromTo("#alcard", {{ opacity: 0, x: -140 }}, {{ opacity: 1, x: 0, duration: 0.5, ease: "expo.out", immediateRender: false }}, 76.3);
        afterIn("#aL", 76.4, 0.005);
        tl.fromTo("#arcard", {{ opacity: 0, x: 140 }}, {{ opacity: 1, x: 0, duration: 0.5, ease: "expo.out", immediateRender: false }}, 76.9);
        afterIn("#aR", 77.0, 0.007);
        cam(76.8, 0.55, {{ r: 0 }}, "sine.out");
        cam(77.5, 0.7, {{ x: {ALC[0] - 30}, y: {ALC[1]}, s: 1.2 }}, "power3.inOut");
        cam(78.5, 0.5, {{ x: {ARC[0]}, y: {ARC[1]}, s: 1.2 }}, "power3.inOut");
        tl.fromTo('#aL .ln[data-ln="2"]', {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.12)", duration: 0.25, immediateRender: false }}, 78.0);
        tl.fromTo('#aR .ln[data-ln="2"]', {{ backgroundColor: "rgba(181,118,20,0)" }}, {{ backgroundColor: "rgba(181,118,20,0.16)", duration: 0.25, immediateRender: false }}, 78.7);
        pop("#appr", 79.0, "50% 0%");
        cam(79.0, 0.8, {{ x: {ARC[0] + 20}, y: {(AR[1] - 100 + APB) / 2}, s: 1.12 }}, "power3.inOut");
        tl.fromTo("#cursor", {{ opacity: 0, x: 0, y: 0 }}, {{ opacity: 1, duration: 0.2, immediateRender: false }}, 79.4);
        tl.to("#cursor", {{ x: {btn_x} - {AR[0] + AR[2] - 40}, y: {btn_y} - {AR[1] + AR[3] + 520}, duration: 0.75, ease: "power3.inOut" }}, 79.5);
        tl.to("#cursor", {{ scale: 0.82, duration: 0.08, yoyo: true, repeat: 1, transformOrigin: "10% 10%" }}, 80.45);
        tl.to("#abtn", {{ scale: 0.92, duration: 0.08, yoyo: true, repeat: 1 }}, 80.45);
        tl.to("#ast", {{ opacity: 0, duration: 0.15 }}, 80.55);
        tl.to("#aok", {{ opacity: 1, duration: 0.15 }}, 80.6);
        tl.to("#appr", {{ borderColor: "#356b49", duration: 0.2 }}, 80.55);
        tl.fromTo('#aR .ln[data-ln="4"], #aR .ln[data-ln="5"]', {{ backgroundColor: "rgba(66,123,88,0)" }}, {{ backgroundColor: "rgba(66,123,88,0.18)", duration: 0.25, stagger: 0.4, immediateRender: false }}, 80.6);
        tl.to("#cursor", {{ opacity: 0, duration: 0.3 }}, 81.3);
        cam(81.0, 0.9, {{ x: {ALC[0] - 80}, y: {(AL[1] - 100 + AL[1] + AL[3] + 160) / 2}, s: 1.1 }}, "power3.inOut");
        cam(82.0, 2.3, {{ s: 1.12 }}, "sine.inOut");
        pop("#adone", 81.4, "0% 0%");
        // push into the model id: which provider?
        cam(84.5, 0.9, {{ x: {AL[0] + 17 * 20.4}, y: {AL[1] + 8 * 50 + 25}, s: 2.6 }}, "power3.in");
        tl.fromTo('#aL .ln[data-ln="8"]', {{ backgroundColor: "rgba(179,0,0,0)" }}, {{ backgroundColor: "rgba(179,0,0,0.12)", duration: 0.25, immediateRender: false }}, 84.5);
""")

# ============================================================ PROVIDERS (86-99)
P1 = tired("rP1", "bP1", "b_anthropic", "shell", 26000, 3000, 36, 54, """{"id":"msg_01...","type":"message","role":"assistant","content":[{"type":"text","text":"..."}],"stop_reason":"end_turn"}
x-api-key: ...    anthropic-version: 2023-06-01    max_tokens is required
""")
P2 = tired("rP2", "bP2", "b_gemini", "shell", 29400, 3000, 26, 40, """{ "candidates": [ { "content": { "parts": [ { "text": "..." } ], "role": "model" } } ] }
x-goog-api-key: ...   :generateContent   v1beta
""")
P3 = tired("rP3", "bP3", "b_bedrock", "python", 32800, 3000, 28, 40, """response["output"]["message"]["content"][0]["text"]
inferenceConfig={"maxTokens": 512, "temperature": 0.5, "topP": 0.9}
boto3.client("bedrock-runtime", region_name="us-east-1")
""")
SX, SY = 29565, 5500
PL = []
for k, (P_, nm) in enumerate([(P1, "a_anthropic"), (P2, "a_gemini"), (P3, "a_bedrock")]):
    x, y, w, h = P_["rect"]
    lw = dims(nm)[1] * 0.6 * 48
    cw = lw + 100
    cx0, cy0 = x + (w - cw) / 2, y + h - 175
    html(f'<div class="plcard" id="plc{k + 1}" style="left:{cx0:.0f}px;top:{cy0:.0f}px;width:{cw:.0f}px;height:130px"></div>')
    lx, ly = cx0 + 50, cy0 + 27
    code(f"plg{k + 1}", nm, "ruby", round(lx), round(ly), 48, 76, extra_cls="shown")
    PL.append((lx, ly, cx0 + cw / 2, cy0 + 65))
    bx, by, bfs, blh = P_["code"]
    rn = ["r_anthropic", "r_gemini", "r_bedrock"][k]
    rx = bx + dims(["b_anthropic", "b_gemini", "b_bedrock"][k])[1] * 0.6 * bfs + 70
    ry = by + blh * 1.5
    html(f'<div class="rsp" id="rsb{k + 1}" data-layout-ignore style="left:{rx - 30:.0f}px;top:{ry - 64:.0f}px;width:{dims(rn)[1] * 0.6 * 26 + 60:.0f}px;height:{dims(rn)[0] * 38 + 94:.0f}px"><span>RESPONSE: TEXT IN HERE</span></div>')
    code(f"rs{k + 1}", rn, "json", round(rx), round(ry), 26, 38, dark=True)
for k in range(3):
    code(f"pst{k + 1}", ["a_anthropic", "a_gemini", "a_bedrock"][k], "ruby", SX, SY + 76 * k, 48, 76)
css(".rsp { position: absolute; border-radius: 14px; background: rgba(255,255,255,0.05); border: 2px solid rgba(255,255,255,0.1); opacity: 0; } .rsp span { position: absolute; left: 28px; top: 16px; font-family: var(--sans); font-weight: 700; font-size: 20px; letter-spacing: 0.16em; color: #a89984; }")
css(".plcard { position: absolute; border-radius: 18px; background: var(--card); border: 2px solid var(--line); box-shadow: 0 30px 80px rgba(0,0,0,0.35); } #plg1, #plg2, #plg3 { z-index: 1 } #rs1, #rs2, #rs3 { z-index: 1 }")
wall = open(os.path.join(ROOT, "src/partials/wall.html")).read() if os.path.exists(os.path.join(ROOT, "src/partials/wall.html")) else ""
html(f'<div id="pwall" style="position:absolute;left:28300px;top:5880px;width:4200px">{wall}</div>')
html('<div class="bigtype" id="pcap" style="left:28300px;top:6560px;width:4200px;text-align:center;font-size:96px;opacity:0">19 providers. <span style="color:var(--red)">One Ruby API.</span></div>')
css('''#pwall { display: flex; flex-direction: column; align-items: center; gap: 56px; transform: scale(1.08); transform-origin: 50% 0; }
#pwall .wall-row { display: flex; justify-content: center; align-items: center; gap: 80px; }
#pwall .logo { display: flex; align-items: center; gap: 18px; height: 80px; opacity: 0; }
#pwall .lw-mark { height: 60px; width: auto; display: block; }
#pwall .lw-text { height: 48px; width: auto; display: block; }
#pwall .lw-wide { height: 52px; width: auto; display: block; }
#pwall .lw-word { font-family: var(--sans); font-weight: 600; font-size: 50px; letter-spacing: -0.02em; color: #111; white-space: nowrap; }''')
def pc(p): return p["c"]
PJ = []
for k, P_, sty, seed, lab, mk, shk, whip, dur, sq, rot in [
        (1, P1, "implode", 31, "its own headers", (1, 3), 10, 85.5, 0.8, 89.05, 1.5),
        (2, P2, "slam", 37, "its own auth header", (1, 1), 10, 90.0, 0.6, 92.55, -1.5),
        (3, P3, "fold", 41, "its own SDK, in Python", (0, 3), 12, 93.5, 0.6, 96.05, 1.5)]:
    cx, cy = pc(P_)
    s0 = P_["s"]
    kx, ky = PL[k - 1][2], PL[k - 1][3]
    a = whip + dur
    pm = ["claude-opus-5-5", "gemini-3.8-flash", "claude-sonnet-5 bedrock"][k - 1]
    PJ.append(f"""
        cam({whip}, {dur}, {{ x: {cx}, y: {cy}, s: {s0}, r: {rot} }}, "power4.inOut");
        whipBlur({whip}, {dur}, 8);
        cam({a}, {sq - a - 0.05:.2f}, {{ s: {s0 * 1.04:.4f}, r: {rot * 0.4:.2f} }}, "sine.inOut");
        mark("#bP{k}", {mk[0]}, {mk[1]}, {a + 0.1:.2f}, 1.0, "{lab}");
        tl.fromTo("#rsb{k}", {{ opacity: 0, x: 40 }}, {{ opacity: 1, x: 0, duration: 0.35, ease: "expo.out", immediateRender: false }}, {a + 1.0:.2f});
        tl.fromTo("#rs{k} .ln", {{ opacity: 0, x: 30 }}, {{ opacity: 1, x: 0, duration: 0.3, stagger: 0.04, ease: "expo.out", immediateRender: false }}, {a + 1.05:.2f});
        mark("#rs{k}", {3 if k == 1 else 4}, {3 if k == 1 else 4}, {a + 1.6:.2f}, {sq - a - 1.75:.2f}, "");
        tl.to("#rsb{k} span", {{ color: "#fb4934", duration: 0.2 }}, {a + 1.6:.2f});
        collapseRegion("#rP{k}", {kx}, {ky}, {sq - 0.05:.2f}, 0.5);
        tl.to("#rsb{k}", {{ opacity: 0, duration: 0.2 }}, {sq:.2f});
        compress("#bP{k}", "#plg{k}", {sq}, "{sty}", {{ match: "{pm}", dur: 0.45, seed: {seed}, shake: {shk}, keepAfter: true }});
        compress("#rs{k}", "#plg{k}", {sq + 0.05:.2f}, "{sty}", {{ match: "", dur: 0.4, seed: {seed + 1}, keepAfter: true, noFx: true, noCam: true, noRegion: true }});""")
PJ = "\n".join(PJ)
warp([[0, 2]])
js(f"""
        // ======== PROVIDERS (climax) ========
        // each provider's API next to its one RubyLLM line; the response shapes differ; the provider side squeezes into the line
        {PJ}
        // the three lines, together: the camera leaves the last world and finds them waiting above the wall
        cam(97.0, 0.9, {{ x: {SX + 835}, y: {SY + 114}, s: 0.85 }}, "power3.inOut");
        whipBlur(97.0, 0.9, 6);
        tl.fromTo("#pst1 .t, #pst2 .t, #pst3 .t", {{ opacity: 0, y: 18 }}, {{ opacity: 1, y: 0, duration: 0.3, stagger: 0.012, ease: "back.out(2)", immediateRender: false }}, 97.35);
        cam(98.0, 1.2, {{ x: 30400, y: 6100, s: 0.6 }}, "power3.inOut");
        tl.fromTo("#pwall .logo", {{ opacity: 0, y: 80, scale: 0.6 }}, {{ opacity: 1, y: 0, scale: 1, duration: 0.5, ease: "back.out(1.8)", stagger: {{ each: 0.035, from: "center" }}, immediateRender: false }}, 98.0);
        tl.fromTo("#pcap", {{ opacity: 0, y: 30 }}, {{ opacity: 1, y: 0, duration: 0.45, ease: "expo.out", immediateRender: false }}, 99.3);
        cam(99.2, 2.1, {{ s: 0.62, r: -0.5 }}, "sine.inOut");
""")

# ============================================================ OPERATIONS (film 103.5-132.5)
OPS = [
  ("speak", "b_speak", "shell", "a_speak", (1, 2, "auth and JSON, again"), "implode", "b_transcribe", "shell", "a_transcribe", (3, 5, "multipart form upload"), "vacuum"),
  ("paint", "b_paint", "shell", "a_paint", (5, 5, "decode base64 yourself"), "shatter", "b_animate", "shell", "a_animate", (5, 7, "poll until it's done"), "fold"),
  ("embed", "b_embed", "shell", "a_embed", (8, 8, "dig out the vector"), "slam", "b_rerank", "shell", "a_rerank", (5, 9, "another shape"), "implode"),
  ("ocr", "b_ocr", "shell", "a_ocr", (7, 7, "base64 again"), "fold", "b_moderate", "ruby", "a_moderate", (1, 1, "a constant for a model id"), "shatter"),
]
OPM = [("Welcome to the show! speech.mp3", "speech.mp3"), ("red panda writing Ruby panda.png", "red panda writing Ruby panda.mp4"),
       ("Ruby is elegant and expressive", "How do reset my password? rerank-v3.5"), ("", "Some user-generated content")]
OPT0 = [99.0, 105.5, 113.5, 121.0]
OPLEN = [6.5, 8.0, 7.5, 7.0]
OX, OY = 27200, 8600
TW, TH, TG = 980, 563, 60
GW = 2 * TW + TG
SA = 0.88
paint_svg = open(os.path.join(ROOT, "src/partials/paint.svg")).read()
# voice note bubble
bars = [abs(math.sin(i * 1.7 + 1.3) * 0.6 + math.sin(i * 0.43 + 2.6) * 0.4) * 90 * math.sin(math.pi * (i + 0.5) / 40) + 10 for i in range(40)]
vbars = "".join(f'<i style="height:{h:.0f}px"></i>' for h in bars)
voice = f'''<div id="vnote"><div id="vbg"></div><div class="vrow"><div class="vplay"><svg viewBox="0 0 24 24" width="40" height="40"><path id="vtri" d="M8 5 L19 12 L8 19 Z" fill="#fff"/><g id="vpause" opacity="0"><rect x="7" y="5" width="3.6" height="14" rx="1" fill="#fff"/><rect x="13.4" y="5" width="3.6" height="14" rx="1" fill="#fff"/></g></svg></div>
<div class="vbars">{vbars}</div><div class="vtime">0:02</div></div><div id="vtext"></div><div class="vmeta">speech.mp3</div></div>'''
# vector numbers
VEC = [0.0182, -0.0417, 0.1093, 0.0521, -0.0764, 0.0338, -0.0129, 0.0906, -0.0453, 0.0287, -0.0612, 0.0775]
def _vn(k, v):
    t = f"{v:.4f}," if v < 0 else f" {v:.4f},"
    return ('<span class="vb">[</span>' if k == 0 else " ") + f'<span class="vn">{t}</span>' + ("\n" if k % 3 == 2 else "")
vec_html = '<div class="vlab tlab">VECTORS</div><div id="vecnums">' + "".join(_vn(k, v) for k, v in enumerate(VEC)) + '  <span class="vn">…</span> <span class="vb">]</span></div>'
DOCS = [("Invoices arrive by email.", 0.04), ("Reset your password in Settings.", 0.98), ("Our office is closed on Sundays.", 0.01),
        ('Use "Forgot password" to get a reset link.', 0.91), ("Two-factor codes expire after 30 seconds.", 0.12)]
order = sorted(range(5), key=lambda k: -DOCS[k][1])
rank_of = {d: r for r, d in enumerate(order)}
RKH, RKG = 78, 12
rer_html = '<div class="tlab">RANKED.RESULTS</div><div id="rklist">' + "".join(
    f'<div class="rk2" id="rkd{k}" style="top:{k * (RKH + RKG)}px"><b id="rkn{k}">{rank_of[k] + 1}</b><span>{text_esc(d)}</span><i id="rks{k}">{s_:.2f}</i></div>' for k, (d, s_) in enumerate(DOCS)) + "</div>"
pdf_html = '''<div id="pdfv" data-layout-allow-overlap><div class="pdfbar"><span>contract.pdf</span><span>1 / 3</span></div><div class="pdfpage">
<div class="pt">SERVICE AGREEMENT</div><div class="ph">1. Term</div><div class="pp">This agreement starts on the effective date and continues for twelve months.</div>
<div class="ph">2. Fees</div><div class="pp">Fees are invoiced monthly.</div></div></div>
<div id="mdv" data-layout-allow-overlap><span class="mh"># Service Agreement</span>

<span class="mh">## 1. Term</span>

This agreement starts on the effective
date and continues for twelve months.

<span class="mh">## 2. Fees</span>
</div><div id="scanl"></div>'''
TILES = {
  "speak": ("VOICE", None),
  "paint": (paint_svg, 'VIDEO'),
  "embed": ('<div style="padding:40px 44px">' + vec_html + '</div>', '<div style="padding:34px 40px">' + rer_html + '</div>'),
  "ocr": (pdf_html,
          '<div style="text-align:center"><svg viewBox="0 0 220 240" width="260" height="284" style="margin-top:60px"><path d="M110 12 L200 44 L200 116 C200 172 160 210 110 230 C60 210 20 172 20 116 L20 44 Z" fill="#e4eee6" stroke="#427b58" stroke-width="6"/><path d="M70 122 L100 152 L152 92" stroke="#427b58" stroke-width="13" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg><div style="font-family:var(--mono);font-size:64px;color:#8f3f71;margin-top:30px">flagged? false</div></div>'),
}
css('''.tile { position: absolute; border-radius: 26px; overflow: hidden; background: var(--card); border: 2px solid var(--line); box-shadow: 0 40px 100px rgba(66,42,34,0.15); opacity: 0; }
.tile > svg { display: block; width: 100%; height: 100%; }
.tlab { font-family: var(--sans); font-weight: 700; font-size: 26px; letter-spacing: 0.16em; color: var(--soft); }
#vnote { position: absolute; left: 0; top: 0; width: 100%; height: 290px; padding: 30px 40px 26px; }
#vbg { position: absolute; inset: 0; border-radius: 30px 30px 30px 8px; background: #fffdfb; border: 2px solid var(--line); box-shadow: 0 30px 80px rgba(66,42,34,0.14); transform-origin: 50% 0; }
.vrow, #vtext { position: relative; }
.vrow { display: flex; align-items: center; gap: 30px; }
.vplay { width: 88px; height: 88px; border-radius: 50%; background: #b30000; display: flex; align-items: center; justify-content: center; flex: none; }
.vbars { flex: 1; display: flex; align-items: center; gap: 9px; height: 110px; }
.vbars i { display: block; flex: 1; border-radius: 5px; background: #cdbfb8; }
.vtime { font-family: var(--mono); font-size: 32px; color: var(--soft); }
#vtext { font-family: var(--serif); font-weight: 600; font-size: 64px; color: var(--heading); line-height: 1.2; margin-top: 24px; padding-left: 118px; }
.vmeta { position: absolute; right: 40px; top: 190px; font-family: var(--mono); font-size: 26px; color: var(--soft); }
#vecnums { margin-top: 26px; font-family: var(--mono); font-size: 44px; line-height: 1.55; color: #8f3f71; white-space: pre; }
#vecnums .vn, #vecnums .vb { opacity: 0; } #vecnums .vb { color: var(--text); }
#rklist { position: relative; margin-top: 22px; height: 440px; }
.rk2 { position: absolute; left: 0; right: 0; height: 78px; display: flex; align-items: center; gap: 22px; padding: 0 26px; border-radius: 16px; border: 2px solid var(--line); background: #fff; font-family: var(--sans); font-size: 30px; color: var(--text); opacity: 0; }
.rk2 b { width: 34px; font-family: var(--mono); font-weight: 500; color: var(--red); opacity: 0; }
.rk2 i { margin-left: auto; font-style: normal; font-family: var(--mono); font-size: 30px; color: var(--red); opacity: 0; }
#pdfv, #mdv { position: absolute; inset: 0; }
#pdfv { background: #525659; }
.pdfbar { height: 54px; display: flex; justify-content: space-between; align-items: center; padding: 0 26px; background: #323639; font-family: var(--sans); font-size: 22px; color: #e8eaed; }
.pdfpage { position: absolute; left: 50%; top: 80px; width: 560px; height: 740px; margin-left: -280px; background: #fff; box-shadow: 0 6px 18px rgba(0,0,0,0.35); padding: 56px 60px; font-family: "Times New Roman", Georgia, serif; color: #111; }
.pt { font-size: 30px; font-weight: 700; letter-spacing: 0.08em; text-align: center; margin-bottom: 30px; }
.ph { font-size: 22px; font-weight: 700; margin: 16px 0 6px; }
.pp { font-size: 20px; line-height: 1.5; text-align: justify; }
#mdv { background: #fffdfb; padding: 40px 50px; font-family: var(--mono); font-size: 32px; line-height: 1.45; color: var(--text); white-space: pre; clip-path: inset(0 0 100% 0); }
#mdv .mh { color: #b30000; }
#scanl { position: absolute; left: 0; right: 0; top: 0; height: 4px; background: #b30000; box-shadow: 0 0 24px 6px rgba(179,0,0,0.35); opacity: 0; }''')
def tsize(name, fs, lh, extra_w):
    n, m = dims(name)
    cw, ch = m * 0.6 * fs, n * lh
    w = cw + extra_w
    h = w * 9 / 16
    if h < ch + 260:
        h = ch + 260
        w = h * 16 / 9
    return round(w), round(h)
opjs = []
x_next, oy_next = OX, OY
OPC = []
for i, (key, lb, llang, la, lmk, lst, rb, rlang, ra, rmk, rst) in enumerate(OPS):
    t0 = OPT0[i]
    lw_, lh_ = tsize(lb, 26, 38, 500)
    rw_, rh_ = tsize(rb, 26, 38, 500)
    x0 = x_next
    OYi = oy_next - (i > 0) * max(lh_, rh_) / 2
    L = tired(f"oLr{i}", f"oLb{i}", lb, llang, x0, OYi, 26, 38, "curl ... -H \"Authorization: Bearer $API_KEY\" -H \"Content-Type: application/json\"\n", extra_w=500, pad=0)
    R = tired(f"oRr{i}", f"oRb{i}", rb, rlang, x0 + L["rect"][2] + 60, OYi, 26, 38, "curl ... -H \"Authorization: Bearer $API_KEY\" -H \"Content-Type: application/json\"\n", extra_w=500, pad=0)
    tot_w = L["rect"][2] + 60 + R["rect"][2]
    top_h = max(L["rect"][3], R["rect"][3])
    ay = OYi + top_h + 140
    code(f"oLa{i}", la, "ruby", x0 + 40, ay, 42, 64)
    code(f"oRa{i}", ra, "ruby", x0 + 40, ay + 72, 42, 64)
    ty_ = ay + 180
    tl_, tr_ = TILES[key]
    if tl_ == "VOICE":
        html(f'<div class="tile" id="oT{i}a" style="left:{x0 + 200}px;top:{ty_ + 40}px;width:{GW - 400}px;height:340px;overflow:visible;background:none;border:none;box-shadow:none">{voice}</div>')
    else:
        if tr_ == "VIDEO":
            k = max(TW / 565, TH / 320)
            tr_ = f'<video id="opvid" src="assets/media/panda.mp4" data-start="{t0 + 3.1 + 4.5:.2f}" data-duration="{OPLEN[i] - 3.1 + 0.3:.2f}" data-media-start="0.3" data-track-index="2" muted playsinline style="position:absolute;left:{-142 * k:.0f}px;top:0;width:{848 * k:.0f}px;height:{480 * k:.0f}px"></video>'
        html(f'<div class="tile" id="oT{i}a" style="left:{x0}px;top:{ty_}px;width:{TW}px;height:{TH}px">{tl_}</div>')
        html(f'<div class="tile" id="oT{i}b" style="left:{x0 + TW + TG}px;top:{ty_}px;width:{TW}px;height:{TH}px">{tr_}</div>')
    cxw = x0 + tot_w / 2
    s_t = round(1920 / tot_w, 4)
    after_c = (x0 + GW / 2, ay + (180 + TH) / 2)
    x_next, oy_next = x0 + max(GW + 400, tot_w + 150), after_c[1]
    last_after = after_c
    OPC.append((x0, ay, ty_))
    opjs.append(f"""
        // ops {key}
        cam({t0 - 0.5}, 0.8, {{ x: {cxw}, y: {OYi + top_h / 2}, s: {s_t}, r: {(-1) ** i * 1.2} }}, "power4.inOut");
        whipBlur({t0 - 0.5}, 0.8, 7);
        cam({t0 + 0.3}, 1.75, {{ s: {s_t * 1.04:.4f}, r: 0 }}, "sine.inOut");
        mark("#oLb{i}", {lmk[0]}, {lmk[1]}, {t0 + 0.6}, 1.1, {json.dumps(lmk[2])});
        mark("#oRb{i}", {rmk[0]}, {rmk[1]}, {t0 + 1.1}, 0.9, {json.dumps(rmk[2])});
        collapseRegion("#oLr{i}", {x0 + 40 + 300}, {ay + 32}, {t0 + 2.0}, 0.5);
        collapseRegion("#oRr{i}", {x0 + 40 + 300}, {ay + 104}, {t0 + 2.05}, 0.45);
        compress("#oLb{i}", "#oLa{i}", {t0 + 2.05}, "{lst}", {{ match: {json.dumps(OPM[i][0])}, dur: 0.45, stage: 1.2, shake: 3, noCam: true }});
        compress("#oRb{i}", "#oRa{i}", {t0 + 2.1}, "{rst}", {{ match: {json.dumps(OPM[i][1])}, dur: 0.4, stage: 1.2, shake: 2, from: "below", camTo: {{ x: {after_c[0]}, y: {after_c[1] - 60}, s: {SA} }} }});
        cam({t0 + 3.3}, {OPLEN[i] - 3.8:.2f}, {{ s: {SA * 1.03:.4f} }}, "sine.inOut");
""")
    if tl_ != "VOICE":
        opjs.append(f'''        tl.fromTo("#oT{i}a", {{ opacity: 0, y: 60, scale: 0.95 }}, {{ opacity: 1, y: 0, scale: 1, duration: 0.45, ease: "back.out(1.5)", immediateRender: false }}, {t0 + 2.8});
        tl.fromTo("#oT{i}b", {{ opacity: 0, y: 60, scale: 0.95 }}, {{ opacity: 1, y: 0, scale: 1, duration: 0.45, ease: "back.out(1.5)", immediateRender: false }}, {t0 + 3.1});''')
T0S, T1S, T2S, T3S = OPT0
rk_moves = ",".join(f"[{k},{rank_of[k]}]" for k in range(5))
opjs.append(f"""
        // speak: one voice note, played once, then transcribed in place
        tl.set("#vbg", {{ scaleY: 0.58 }}, {T0S});
        tl.fromTo("#oT0a", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.4, ease: "back.out(1.4)", immediateRender: false }}, {T0S + 2.8});
        tl.fromTo("#vnote .vbars i", {{ scaleY: 0.15 }}, {{ scaleY: 1, duration: 0.35, stagger: 0.012, ease: "power2.out", immediateRender: false }}, {T0S + 2.9});
        tl.set("#vtri", {{ opacity: 0 }}, {T0S + 3.45}); tl.set("#vpause", {{ opacity: 1 }}, {T0S + 3.45});
        tl.fromTo("#vnote .vbars i", {{ backgroundColor: "#cdbfb8" }}, {{ backgroundColor: "#b30000", duration: 0.05, stagger: 0.035, ease: "none", immediateRender: false }}, {T0S + 3.5});
        tl.set("#vtri", {{ opacity: 1 }}, {T0S + 4.95}); tl.set("#vpause", {{ opacity: 0 }}, {T0S + 4.95});
        tl.fromTo('#oRa0 .ln[data-ln="0"]', {{ backgroundColor: "rgba(181,118,20,0)" }}, {{ backgroundColor: "rgba(181,118,20,0.16)", duration: 0.25, immediateRender: false }}, {T0S + 4.9});
        tl.fromTo("#vbg", {{ scaleY: 0.58 }}, {{ scaleY: 1, duration: 0.35, ease: "power3.out", immediateRender: false }}, {T0S + 5.0});
        stream("#vtext", "Welcome to the show!", {T0S + 5.15}, 0.12);
        // paint: strokes draw in
        const strokes = Array.from(document.querySelectorAll(".pp-stroke"));
        strokes.forEach((p, k) => {{ const Lx = Math.ceil(p.getTotalLength()) + 20; p.setAttribute("stroke-dasharray", Lx + " " + Lx); p.setAttribute("stroke-dashoffset", String(Lx));
          tl.fromTo(p, {{ strokeDashoffset: Lx }}, {{ strokeDashoffset: 0, duration: 0.4, ease: "power1.inOut", immediateRender: false }}, {T1S + 2.85} + k * 0.15); }});
        tl.fromTo("#pp-under", {{ opacity: 0 }}, {{ opacity: 0.25, duration: 0.2, immediateRender: false }}, {T1S + 2.8});
        // embed: the numbers themselves
        tl.fromTo("#vecnums .vb, #vecnums .vn", {{ opacity: 0, y: 8 }}, {{ opacity: 1, y: 0, duration: 0.15, stagger: 0.07, ease: "power2.out", immediateRender: false }}, {T2S + 3.0});
        // rerank: five documents in, then sorted by score
        tl.fromTo(".rk2", {{ opacity: 0, x: 30 }}, {{ opacity: 1, x: 0, duration: 0.3, stagger: 0.08, ease: "power2.out", immediateRender: false }}, {T2S + 3.3});
        [{rk_moves}].forEach(([k, r]) => {{
          tl.to("#rkd" + k, {{ y: (r - k) * {RKH + RKG}, duration: 0.6, ease: "power3.inOut" }}, {T2S + 4.6});
          tl.fromTo("#rks" + k, {{ opacity: 0 }}, {{ opacity: 1, duration: 0.25, immediateRender: false }}, {T2S + 4.3});
          tl.fromTo("#rkn" + k, {{ opacity: 0 }}, {{ opacity: 1, duration: 0.25, immediateRender: false }}, {T2S + 4.9});
          if (r < 2) tl.to("#rkd" + k, {{ borderColor: "#b30000", duration: 0.25 }}, {T2S + 5.2});
          if (r > 2) tl.to("#rkd" + k, {{ opacity: 0.55, duration: 0.25 }}, {T2S + 5.2});
        }});
        tl.fromTo('#oRa2 .ln[data-ln="0"]', {{ backgroundColor: "rgba(181,118,20,0)" }}, {{ backgroundColor: "rgba(181,118,20,0.16)", duration: 0.25, immediateRender: false }}, {T2S + 4.3});
        // ocr: the PDF page becomes Markdown
        tl.fromTo("#scanl", {{ opacity: 0, y: 0 }}, {{ opacity: 1, duration: 0.1, immediateRender: false }}, {T3S + 3.7});
        tl.to("#scanl", {{ y: {TH}, duration: 0.9, ease: "power1.inOut" }}, {T3S + 3.7});
        tl.to("#scanl", {{ opacity: 0, duration: 0.15 }}, {T3S + 4.6});
        tl.set("#pdfv", {{ opacity: 0 }}, {T3S + 4.65});
        tl.fromTo("#mdv", {{ clipPath: "inset(0% 0% 100% 0%)" }}, {{ clipPath: "inset(0% 0% 0% 0%)", duration: 0.9, ease: "power1.inOut", immediateRender: false }}, {T3S + 3.7});
""")
warp([[0, 4.5]])
js("\n".join(opjs))


# ============================================================ EVERYTHING ELSE (film 132-144): a bento of features around RubyLLM
GX0, GY0, GW, GH, GG = 150, 150, 1620, 900, 22
BW = (GW - 3 * GG) / 4
BH = (GH - 3 * GG) / 4
def cell(c, r, cs=1, rs=1):
    return (GX0 + c * (BW + GG), GY0 + r * (BH + GG), BW * cs + GG * (cs - 1), BH * rs + GG * (rs - 1))
ORDER = [(0, 0), (1, 0), (2, 0), (3, 0), (3, 1), (3, 2), (3, 3), (2, 3), (1, 3), (0, 3), (0, 2), (0, 1)]
TILES = [
  ("Model fallbacks", "chat.with_fallbacks(\"claude-haiku-4-5\")", """
    <div class="mchip" id="b0a" style="left:18px;top:62px">claude-sonnet-5<em id="b0x">&#x2715;</em></div>
    <svg class="bsvg" viewBox="0 0 352 110" style="left:18px;top:40px;width:352px;height:110px"><path id="b0p" d="M150 18 C 190 -14, 250 -6, 262 56" fill="none" stroke="#b30000" stroke-width="3" stroke-linecap="round"/><path id="b0h" d="M252 46 L262 60 L271 46" fill="none" stroke="#b30000" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>
    <div class="mchip" id="b0b" style="left:196px;top:104px">claude-haiku-4-5<em class="ok" id="b0c">&#x2713;</em></div>"""),
  ("Prompt caching", "chat.with_caching(ttl: \"1h\")", """
    <div class="pbar" style="left:18px;top:52px;width:220px"></div><div class="pbar" style="left:18px;top:72px;width:190px"></div><div class="pbar" style="left:18px;top:92px;width:230px"></div><div class="pbar" style="left:18px;top:112px;width:160px"></div>
    <div class="hit" id="b1h">CACHE HIT</div>
    <div class="cbar" style="left:18px;top:140px;width:320px"><i id="b1f" style="width:86%"></i></div>"""),
  ("Extended thinking", "chat.with_thinking(effort: :high)", """
    <div class="thought" id="b2t"><i class="d" id="b2d0"></i><i class="d" id="b2d1"></i><i class="d" id="b2d2"></i></div>
    <i class="tb1" id="b2s1"></i><i class="tb2" id="b2s2"></i>
    <div class="effort" id="b2e">effort: high</div>"""),
  ("Web search", "chat.with_provider_tools(:web_search)", """
    <div class="sbar" id="b3s"><svg viewBox="0 0 24 24" width="18" height="18"><circle cx="11" cy="11" r="7" fill="none" stroke="#796b67" stroke-width="2.5"/><path d="M16 16 L21 21" stroke="#796b67" stroke-width="2.5" stroke-linecap="round"/></svg>latest Ruby release</div>
    <div class="sres" id="b3r"><b>Ruby Releases</b><span>The newest Ruby is out with faster YJIT<sup>1</sup></span></div>
    <div class="fnote" id="b3n"><sup>1</sup> ruby-lang.org</div>"""),
  ("Citations", "response.citations", """
    <div class="para" id="b4p"><span>Ruby was created by</span> <mark id="b4m">Yukihiro Matsumoto</mark> <span>in 1993, as a</span> <span>language for programmer joy.</span></div>
    <div class="cite" id="b4c">facts.txt, p. 5</div>"""),
  ("Cost tracking", "chat.cost.total", """
    <svg class="bsvg" viewBox="0 0 200 110" style="left:24px;top:44px;width:200px;height:110px"><path d="M20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#eadfd9" stroke-width="16" stroke-linecap="round"/><path id="b5arc" d="M20 100 A 80 80 0 0 1 180 100" fill="none" stroke="#b30000" stroke-width="16" stroke-linecap="round"/><g id="b5n"><path d="M100 100 L100 34" stroke="#2c2926" stroke-width="5" stroke-linecap="round"/></g><circle cx="100" cy="100" r="9" fill="#2c2926"/></svg>
    <div class="readout" id="b5r">$0.0042</div>"""),
  ("Batches", "RubyLLM.batch(chats)", """
    <div class="job" id="b6j0" style="top:48px"><span>chat 1</span><div class="jb"><i id="b6f0"></i></div><em id="b6c0">&#x2713;</em></div>
    <div class="job" id="b6j1" style="top:84px"><span>chat 2</span><div class="jb"><i id="b6f1"></i></div><em id="b6c1">&#x2713;</em></div>
    <div class="job" id="b6j2" style="top:120px"><span>chat 3</span><div class="jb"><i id="b6f2"></i></div><em id="b6c2">&#x2713;</em></div>"""),
  ("Tool approval", "chat.approve(tool_call)", """
    <div class="apc"><div class="apt" id="b7t">issue_refund(order_id: 42)</div><div class="apb"><span>Deny</span><span class="go" id="b7b">Approve</span></div></div>
    <svg id="b7cur" width="26" height="26" viewBox="0 0 24 24" style="position:absolute;left:300px;top:150px"><path d="M4 2 L4 20 L9 15 L12.5 22 L15.5 20.5 L12 13.5 L19 13.5 Z" fill="#2c2926" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>"""),
  ("The agentic loop", "chat.step until chat.complete?", """
    <svg class="bsvg" viewBox="0 0 352 120" style="left:18px;top:40px;width:352px;height:120px"><ellipse cx="176" cy="62" rx="120" ry="44" fill="none" stroke="#eadfd9" stroke-width="4" stroke-dasharray="2 10" stroke-linecap="round"/>
      <ellipse id="b8o" cx="176" cy="62" rx="120" ry="44" fill="none" stroke="#b30000" stroke-width="18" stroke-linecap="round" stroke-dasharray="0.1 700"/></svg>
    <div class="lnode" style="left:150px;top:36px">think</div><div class="lnode" style="left:300px;top:112px">act</div><div class="lnode" style="left:24px;top:112px">observe</div>"""),
  ("Compaction", "chat.with_compaction(at: 50_000)", """
    <div id="b9s" style="position:absolute;left:18px;top:44px;width:340px;height:110px">
      <i class="msg" style="top:0;width:70%"></i><i class="msg me" style="top:18px;width:55%"></i><i class="msg" style="top:36px;width:82%"></i><i class="msg me" style="top:54px;width:48%"></i><i class="msg" style="top:72px;width:76%"></i><i class="msg me" style="top:90px;width:60%"></i></div>
    <div class="summ" id="b9m">summary of 48 turns</div>"""),
  ("Token counting", "chat.count_tokens(text)", """
    <div class="toks"><span id="bat0">Ruby</span><span id="bat1"> is</span><span id="bat2"> elegant</span><span id="bat3"> and</span><span id="bat4"> expressive</span></div>
    <div class="tcount"><b id="bac">""" + "".join(f'<i id="ban{n}">{n}</i>' for n in range(6)) + """</b> tokens</div>"""),
  ("Model registry", "RubyLLM.models.find(\"claude-sonnet-5\")", """
    <div class="mcard" style="left:18px;top:48px"><b>claude-sonnet-5</b><span class="bd v">vision</span><span class="bd">reasoning</span><span class="bd">citations</span></div>
    <div class="mcard" style="left:18px;top:102px"><b>gemini-3.8-flash</b><span class="bd v">vision</span><span class="bd">video</span><span class="bd">caching</span></div>"""),
]
tiles = []
for k, ((c, r), (lab, snip, body)) in enumerate(zip(ORDER, TILES)):
    x, y, w, h = cell(c, r)
    tiles.append(f'<div class="bt" id="bt{k}" style="left:{x:.0f}px;top:{y:.0f}px;width:{w:.0f}px;height:{h:.0f}px"><div class="btl">{lab}</div>{body}<div class="bsn">{text_esc(snip)}</div></div>')
cx_, cy_, cw_, ch_ = cell(1, 1, 2, 2)
tiles.append(f'<div class="bt core" id="btc" style="left:{cx_:.0f}px;top:{cy_:.0f}px;width:{cw_:.0f}px;height:{ch_:.0f}px"><img src="assets/logos/logotype.svg" alt="RubyLLM" style="width:440px" /><div class="coresn">chat = RubyLLM.chat</div></div>')
film_ovl = ('<div class="bigtype" id="mnote" style="left:0;top:250px;width:1920px;text-align:center;font-size:68px;opacity:0">Another server is three lines away.</div>'
            + '<div id="feat"><div class="bigtype" id="feathl" style="left:0;top:56px;width:1920px;text-align:center;font-size:58px;opacity:0">And everything else you\'d build yourself.</div><div id="bento">' + "".join(tiles) + '</div></div>')
css('''#feat { position: absolute; inset: 0; }
#bento { position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; transform-origin: 0 0; }
.bt { position: absolute; border-radius: 22px; background: #fffdfb; border: 2px solid var(--line); box-shadow: 0 16px 36px rgba(66,42,34,0.1); overflow: hidden; opacity: 0; }
.bt * { position: absolute; }
.bt .btl { left: 18px; top: 12px; font-family: var(--sans); font-weight: 700; font-size: 17px; letter-spacing: 0.02em; color: var(--red); white-space: nowrap; }
.bt .bsn { left: 18px; bottom: 12px; font-family: var(--mono); font-size: 12.5px; color: var(--soft); white-space: nowrap; }
.bt.core { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 26px; background: #fffdfb; border-color: #e7cfc9; box-shadow: 0 30px 80px rgba(179,0,0,0.14); }
.bt.core * { position: static; }
.coresn { font-family: var(--mono); font-size: 26px; color: var(--text); }
.bsvg { overflow: visible; }
.mchip { font-family: var(--mono); font-size: 14px; color: var(--text); background: #fff; border: 2px solid var(--line); border-radius: 10px; padding: 6px 12px; white-space: nowrap; position: absolute; }
.mchip em { position: relative; margin-left: 8px; font-style: normal; font-weight: 700; color: #b30000; opacity: 0; }
.mchip em.ok { color: #356b49; }
.pbar { height: 10px; border-radius: 5px; background: #eadfd9; }
.hit { right: 20px; top: 60px; padding: 8px 14px; border-radius: 10px; background: #356b49; color: #fff; font-family: var(--sans); font-weight: 800; font-size: 16px; letter-spacing: 0.1em; opacity: 0; }
.cbar { height: 12px; border-radius: 6px; background: #eadfd9; overflow: hidden; }
.cbar i { position: absolute; left: 0; top: 0; height: 100%; background: #427b58; border-radius: 6px; transform-origin: 0 50%; }
.thought { left: 90px; top: 50px; width: 200px; height: 74px; border-radius: 40px; background: #f1ece8; border: 2px solid var(--line); }
.thought .d { top: 29px; width: 16px; height: 16px; border-radius: 50%; background: #b30000; }
#b2d0 { left: 58px; } #b2d1 { left: 92px; } #b2d2 { left: 126px; }
.tb1 { left: 70px; top: 128px; width: 18px; height: 18px; border-radius: 50%; background: #f1ece8; border: 2px solid var(--line); }
.tb2 { left: 54px; top: 150px; width: 10px; height: 10px; border-radius: 50%; background: #f1ece8; border: 2px solid var(--line); }
.effort { right: 18px; top: 136px; font-family: var(--mono); font-size: 13px; color: #076678; opacity: 0; }
.sbar { left: 18px; top: 44px; width: 350px; height: 36px; border-radius: 18px; border: 2px solid var(--line); background: #fff; display: flex; align-items: center; gap: 8px; padding-left: 12px; font-family: var(--sans); font-size: 15px; color: var(--text); }
.sbar svg { position: static; }
.sres { left: 18px; top: 88px; width: 350px; font-family: var(--sans); opacity: 0; }
.sres b { position: static; display: block; font-size: 16px; color: #1a57b7; }
.sres span { position: static; display: block; font-size: 14px; color: var(--muted); margin-top: 2px; }
.sres sup, .fnote sup { position: static; color: #b30000; font-weight: 700; }
.fnote { left: 18px; top: 140px; font-family: var(--mono); font-size: 12.5px; color: var(--soft); opacity: 0; }
.para { left: 18px; top: 44px; width: 350px; font-family: var(--serif); font-size: 19px; line-height: 1.4; color: var(--text); }
.para * { position: static; }
.para mark { background: rgba(251,213,73,0.0); color: inherit; border-radius: 4px; padding: 0 2px; }
.cite { right: 18px; top: 134px; padding: 4px 10px; border-radius: 8px; background: #b30000; color: #fff; font-family: var(--mono); font-size: 12.5px; opacity: 0; }
.readout { right: 24px; top: 88px; font-family: var(--mono); font-weight: 500; font-size: 34px; color: var(--text); opacity: 0; }
.job { left: 18px; width: 350px; height: 28px; display: flex; align-items: center; gap: 12px; opacity: 0; }
.job * { position: static; }
.job span { width: 56px; font-family: var(--mono); font-size: 13px; color: var(--text); }
.job .jb { flex: 1; height: 10px; border-radius: 5px; background: #eadfd9; overflow: hidden; }
.job .jb i { display: block; height: 100%; background: #b30000; border-radius: 5px; transform-origin: 0 50%; transform: scaleX(0); }
.job em { font-style: normal; font-weight: 700; color: #356b49; opacity: 0; }
.apc { left: 18px; top: 44px; width: 350px; height: 100px; border-radius: 14px; border: 2px solid var(--line); background: #fff; }
.apt { left: 14px; top: 12px; font-family: var(--mono); font-size: 14px; color: #076678; white-space: nowrap; }
.apb { right: 12px; bottom: 12px; display: flex; gap: 8px; }
.apb span { position: static; padding: 6px 14px; border-radius: 8px; border: 2px solid var(--line); font-family: var(--sans); font-weight: 600; font-size: 14px; color: var(--muted); }
.apb span.go { background: #356b49; border-color: #356b49; color: #fff; }
.lnode { font-family: var(--sans); font-weight: 600; font-size: 14px; color: var(--text); background: #fff; border: 2px solid var(--line); border-radius: 999px; padding: 3px 10px; }
.msg { left: 0; height: 12px; border-radius: 6px; background: #d8ccc5; }
.msg.me { left: auto; right: 0; background: #e8b4ad; }
.summ { left: 18px; top: 86px; width: 350px; height: 40px; border-radius: 12px; background: #b30000; color: #fff; font-family: var(--sans); font-weight: 600; font-size: 15px; display: flex; align-items: center; justify-content: center; opacity: 0; }
.toks { left: 18px; top: 54px; font-family: var(--mono); font-size: 19px; white-space: pre; }
.toks span { position: static; border-radius: 5px; padding: 2px 0; opacity: 0.25; }
#bat0, #bat2, #bat4 { background: rgba(179,0,0,0.12); } #bat1, #bat3 { background: rgba(7,102,120,0.12); }
.tcount { left: 18px; top: 104px; font-family: var(--sans); font-size: 18px; color: var(--muted); padding-left: 44px; }
.tcount b { left: 0; top: -8px; width: 40px; height: 36px; font-family: var(--mono); font-size: 32px; color: var(--text); }
.tcount b i { left: 0; top: 0; font-style: normal; opacity: 0; }
#ban0 { opacity: 1; }
.mcard { width: 350px; height: 44px; display: flex; align-items: center; gap: 6px; padding: 0 10px; border-radius: 12px; border: 2px solid var(--line); background: #fff; }
.mcard * { position: static; }
.mcard b { font-family: var(--mono); font-weight: 500; font-size: 13px; color: var(--text); margin-right: auto; }
.bd { font-family: var(--sans); font-weight: 600; font-size: 11.5px; padding: 3px 7px; border-radius: 999px; background: #f1ece8; color: var(--muted); }
#cloudbg { position: absolute; inset: 0; background: var(--bg); opacity: 0; }''')
S_T = 1.9
def view(c, r, c2, r2):
    x0, y0, w0, h0 = cell(c, r)
    x1, y1, w1, h1 = cell(c2, r2)
    mx, my = (min(x0, x1) + max(x0 + w0, x1 + w1)) / 2, (min(y0, y1) + max(y0 + h0, y1 + h1)) / 2
    return round(960 - mx * S_T), round(540 - my * S_T)
bjs = []
for p in range(6):
    t0 = 123.3 + p * 1.25
    vx, vy = view(*ORDER[2 * p], *ORDER[2 * p + 1])
    if p == 0:
        bjs.append(f'tl.set("#bento", {{ x: {vx}, y: {vy}, scale: {S_T} }}, 122.9);')
        bjs.append(f'tl.fromTo("#bento", {{ scale: {S_T * 1.15:.3f}, x: {round(960 - (960 - vx) / S_T * S_T * 1.15)}, y: {round(540 - (540 - vy) / S_T * S_T * 1.15)} }}, {{ scale: {S_T}, x: {vx}, y: {vy}, duration: 0.8, ease: "expo.out", immediateRender: false }}, 123.0);')
    else:
        bjs.append(f'tl.to("#bento", {{ x: {vx}, y: {vy}, duration: 0.5, ease: "power3.inOut" }}, {t0 - 0.35:.2f});')
    for q in range(2):
        k = 2 * p + q
        ti = t0 + q * 0.14
        bjs.append(f'tl.fromTo("#bt{k}", {{ opacity: 0, y: 24, scale: 0.9 }}, {{ opacity: 1, y: 0, scale: 1, duration: 0.4, ease: "back.out(1.6)", immediateRender: false }}, {ti:.2f});')
# per-tile motion (a = when the tile has landed)
A = [123.3 + (k // 2) * 1.25 + (k % 2) * 0.14 + 0.3 for k in range(12)]
bjs.append(f"""
        // fallbacks: first model fails, the arrow jumps, the second answers
        tl.fromTo("#b0a", {{ x: 0 }}, {{ x: 5, duration: 0.05, yoyo: true, repeat: 5, ease: "none", immediateRender: false }}, {A[0]:.2f});
        tl.to("#b0x", {{ opacity: 1, duration: 0.15 }}, {A[0] + 0.1:.2f}); tl.to("#b0a", {{ opacity: 0.45, duration: 0.2 }}, {A[0] + 0.3:.2f});
        tl.fromTo("#b0p", {{ strokeDasharray: 240, strokeDashoffset: 240 }}, {{ strokeDashoffset: 0, duration: 0.4, ease: "power2.inOut", immediateRender: false }}, {A[0] + 0.3:.2f});
        tl.fromTo("#b0h", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.1, immediateRender: false }}, {A[0] + 0.65:.2f});
        tl.fromTo("#b0b", {{ scale: 1 }}, {{ scale: 1.1, duration: 0.15, yoyo: true, repeat: 1, ease: "power2.out", immediateRender: false }}, {A[0] + 0.72:.2f});
        tl.to("#b0b", {{ borderColor: "#356b49", duration: 0.2 }}, {A[0] + 0.72:.2f}); tl.to("#b0c", {{ opacity: 1, duration: 0.15 }}, {A[0] + 0.78:.2f});
        // caching: the prompt is found, a hit stamps on, cached tokens fill in
        tl.fromTo("#b1h", {{ opacity: 0, scale: 2.2, rotation: -8 }}, {{ opacity: 1, scale: 1, rotation: -4, duration: 0.3, ease: "back.out(2.5)", immediateRender: false }}, {A[1] + 0.2:.2f});
        tl.fromTo("#b1f", {{ scaleX: 0 }}, {{ scaleX: 1, duration: 0.6, ease: "power3.out", immediateRender: false }}, {A[1] + 0.3:.2f});
        // thinking: bubbles rise, dots think
        tl.fromTo(["#b2s2", "#b2s1", "#b2t"], {{ opacity: 0, scale: 0.4 }}, {{ opacity: 1, scale: 1, duration: 0.25, stagger: 0.1, ease: "back.out(2)", immediateRender: false }}, {A[2] - 0.05:.2f});
        tl.fromTo(["#b2d0", "#b2d1", "#b2d2"], {{ y: 0 }}, {{ y: -10, duration: 0.22, stagger: 0.09, yoyo: true, repeat: 15, ease: "sine.inOut", immediateRender: false }}, {A[2] + 0.25:.2f});
        tl.fromTo("#b2e", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.2, immediateRender: false }}, {A[2] + 0.5:.2f});
        // web search: a result with a footnote
        tl.fromTo("#b3r", {{ opacity: 0, y: 10 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "expo.out", immediateRender: false }}, {A[3] + 0.15:.2f});
        tl.fromTo("#b3n", {{ opacity: 0, x: -10 }}, {{ opacity: 1, x: 0, duration: 0.25, ease: "expo.out", immediateRender: false }}, {A[3] + 0.5:.2f});
        // citations: the claim lights up, its source pins to it
        tl.fromTo("#b4m", {{ backgroundColor: "rgba(251,213,73,0)" }}, {{ backgroundColor: "rgba(251,213,73,0.55)", duration: 0.3, immediateRender: false }}, {A[4] + 0.1:.2f});
        tl.fromTo("#b4c", {{ opacity: 0, y: 10 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "back.out(2)", immediateRender: false }}, {A[4] + 0.35:.2f});
        // cost: the meter swings, the total lands
        tl.fromTo("#b5arc", {{ strokeDasharray: 252, strokeDashoffset: 252 }}, {{ strokeDashoffset: 150, duration: 0.7, ease: "power3.out", immediateRender: false }}, {A[5]:.2f});
        tl.fromTo("#b5n", {{ rotation: -90, svgOrigin: "100 100" }}, {{ rotation: -18, duration: 0.7, ease: "back.out(1.6)", immediateRender: false }}, {A[5]:.2f});
        tl.fromTo("#b5r", {{ opacity: 0, y: 8 }}, {{ opacity: 1, y: 0, duration: 0.25, immediateRender: false }}, {A[5] + 0.45:.2f});
        // batches: jobs stack up and finish
        tl.fromTo(["#b6j0", "#b6j1", "#b6j2"], {{ opacity: 0, x: 30 }}, {{ opacity: 1, x: 0, duration: 0.25, stagger: 0.08, ease: "expo.out", immediateRender: false }}, {A[6] - 0.1:.2f});
        tl.fromTo(["#b6f0", "#b6f1", "#b6f2"], {{ scaleX: 0 }}, {{ scaleX: 1, duration: 0.5, stagger: 0.14, ease: "power2.inOut", immediateRender: false }}, {A[6] + 0.15:.2f});
        tl.fromTo(["#b6c0", "#b6c1", "#b6c2"], {{ opacity: 0, scale: 1.8 }}, {{ opacity: 1, scale: 1, duration: 0.2, stagger: 0.14, immediateRender: false }}, {A[6] + 0.62:.2f});
        // approval: the cursor clicks approve
        tl.fromTo("#b7cur", {{ x: 0, y: 0 }}, {{ x: -18, y: -30, duration: 0.45, ease: "power3.inOut", immediateRender: false }}, {A[7]:.2f});
        tl.fromTo("#b7b", {{ scale: 1 }}, {{ scale: 0.9, duration: 0.08, yoyo: true, repeat: 1, immediateRender: false }}, {A[7] + 0.45:.2f});
        tl.to("#b7t", {{ color: "#356b49", duration: 0.2 }}, {A[7] + 0.5:.2f});
        // the loop: step, step, step
        tl.fromTo("#b8o", {{ strokeDashoffset: 0 }}, {{ strokeDashoffset: -548 * 4, duration: 5.6, ease: "none", immediateRender: false }}, {A[8] - 0.2:.2f});
        // compaction: the transcript squeezes into one summary
        tl.fromTo("#b9s", {{ scaleY: 1, transformOrigin: "50% 60%" }}, {{ scaleY: 0.05, scaleX: 0.9, duration: 0.45, ease: "power4.in", immediateRender: false }}, {A[9] + 0.15:.2f});
        tl.to("#b9s", {{ opacity: 0, duration: 0.05 }}, {A[9] + 0.6:.2f});
        tl.fromTo("#b9m", {{ opacity: 0, scaleX: 1.3, scaleY: 0.4 }}, {{ opacity: 1, scaleX: 1, scaleY: 1, duration: 0.5, ease: "elastic.out(1, 0.5)", immediateRender: false }}, {A[9] + 0.6:.2f});
        // tokens: each chunk counts
        {"".join(f'tl.to("#bat{n}", {{ opacity: 1, duration: 0.1 }}, {A[10] + n * 0.12:.2f}); tl.set("#ban{n}", {{ opacity: 0 }}, {A[10] + n * 0.12:.2f}); tl.set("#ban{n + 1}", {{ opacity: 1 }}, {A[10] + n * 0.12:.2f}); ' for n in range(5))}
        // registry: the capability you asked about lights up
        tl.to(".mcard .bd.v", {{ backgroundColor: "#356b49", color: "#ffffff", duration: 0.25, stagger: 0.12 }}, {A[11] + 0.15:.2f});
""")
H = 131.0
bjs.append(f"""
        // THE REVEAL: brace, then the whole bento lands around RubyLLM on the hit
        tl.to("#bento", {{ scale: {S_T * 1.06:.3f}, duration: 0.3, ease: "power2.in" }}, {H - 0.3:.2f});
        tl.to("#bento", {{ x: 0, y: 0, scale: 1, duration: 0.65, ease: "expo.out" }}, {H:.2f});
        tl.fromTo("#btc", {{ opacity: 0, scale: 0.5 }}, {{ opacity: 1, scale: 1, duration: 0.7, ease: "elastic.out(1, 0.55)", immediateRender: false }}, {H + 0.05:.2f});
        tl.fromTo(".bt:not(.core)", {{ scale: 0.94 }}, {{ scale: 1, duration: 0.5, stagger: {{ each: 0.02, from: "random" }}, ease: "back.out(2)", immediateRender: false }}, {H + 0.1:.2f});
        tl.fromTo("#feathl", {{ opacity: 0, y: -20 }}, {{ opacity: 1, y: 0, duration: 0.45, ease: "expo.out", immediateRender: false }}, {H + 0.25:.2f});
        tl.fromTo("#feat", {{ x: 0 }}, {{ x: 10, duration: 0.04, yoyo: true, repeat: 3, ease: "none", immediateRender: false }}, {H:.2f});
        tl.fromTo("#bento", {{ scale: 1, x: 0, y: 0 }}, {{ scale: 1.035, x: -34, y: -19, duration: 2.4, ease: "sine.inOut", immediateRender: false }}, {H + 0.7:.2f});
        tl.to(".mcard .bd:not(.v)", {{ backgroundColor: "#eadfd9", duration: 0.3, stagger: 0.1, yoyo: true, repeat: 1 }}, {H + 0.8:.2f});
""")
warp([[0, 9.5]])
js("""
        // ======== EVERYTHING ELSE ========
        cam(122.5, 1.0, { s: 0.12, r: 8 }, "power3.in");
        tl.fromTo("#cloudbg", { opacity: 0 }, { opacity: 1, duration: 0.5, immediateRender: false }, 123.0);
        tl.set("#world", { autoAlpha: 0 }, 123.55);
""" + "\n".join("        " + x for x in bjs) + """
        // out: straight into the closing line
        cam(134.2, 0.1, { x: %d, y: %d, s: 0.4, r: 4 }, "none");
        tl.to("#feat", { opacity: 0, scale: 1.12, filter: "blur(8px)", duration: 0.4, ease: "power2.in" }, 134.1);
        tl.set("#world", { autoAlpha: 1 }, 134.3);
        tl.to("#cloudbg", { opacity: 0, duration: 0.3 }, 134.3);
""" % (53000 + 1200, 9200 + 200))


# ============================================================ ENDING (138-146)
EX, EY = 53000, 9200
html(f'''<div class="bigtype" id="e1" style="left:{EX}px;top:{EY}px;width:2400px;text-align:center;font-size:96px;white-space:nowrap">
  <span class="w">You</span> <span class="w">don't</span> <span class="w">need</span> <span class="w">Python</span> <span class="w">or</span> <span class="w">JavaScript</span> <span class="w">for</span> <span class="w">AI.</span></div>
<div class="bigtype" id="e2" style="left:{EX}px;top:{EY + 150}px;width:2400px;text-align:center;font-size:260px;line-height:1.1;color:var(--red)"><span class="w">Use</span> <span class="w">Ruby.</span></div>
<div id="eend" style="position:absolute;left:{EX + 1200 - 1100}px;top:{EY + 800}px;width:2200px;display:flex;flex-direction:column;align-items:center">
  <img id="elogo" src="assets/logos/logotype.svg" alt="RubyLLM" style="width:620px;height:auto;margin-bottom:46px;opacity:0" />
  <div class="bigtype" id="etitle" style="position:static;font-size:112px;white-space:nowrap;margin-bottom:56px"><span class="w">The</span> <span class="w" style="color:var(--red)">Ruby-native</span> <span class="w">AI</span> <span class="w">framework.</span></div>
  <div id="erow" style="display:flex;align-items:center;gap:44px"><span id="einst" style="padding:22px 40px;border-radius:16px;border:2px solid var(--line);background:var(--card);font-family:var(--mono);font-size:46px;color:var(--text);box-shadow:0 20px 44px rgba(66,42,34,0.1);opacity:0"><b style="font-weight:400;color:#427b58">$</b> bundle add ruby_llm</span><span id="eurl" style="font-family:var(--sans);font-weight:700;font-size:44px;color:var(--red);opacity:0">rubyllm.com</span></div>
</div>''')
css("#e1 .w, #e2 .w, #etitle .w { opacity: 0; }")
warp([[0, 6.5]])
js(f"""
        // ======== ENDING ========
        cam(137.5, 0.9, {{ x: {EX + 1200}, y: {EY + 200}, s: 0.72, r: 0 }}, "power4.inOut");
        whipBlur(137.5, 0.9, 6);
        tl.fromTo("#e1 .w", {{ opacity: 0, y: 50, rotationX: -60 }}, {{ opacity: 1, y: 0, rotationX: 0, duration: 0.4, ease: "expo.out", stagger: 0.06, immediateRender: false }}, 137.6);
        tl.fromTo("#e2 .w", {{ opacity: 0, scale: 2.4 }}, {{ opacity: 1, scale: 1, duration: 0.3, ease: "power4.out", stagger: 0.3, immediateRender: false }}, 139.5);
        shake(139.8, 12);
        cam(138.4, 2.4, {{ s: 0.78 }}, "sine.inOut");
        cam(141.0, 0.9, {{ x: {EX + 1200}, y: {EY + 1080}, s: 0.8 }}, "power3.inOut");
        tl.to(["#e1", "#e2"], {{ opacity: 0, duration: 0.5 }}, 141.1);
        tl.fromTo("#elogo", {{ opacity: 0, scale: 0.6 }}, {{ opacity: 1, scale: 1, duration: 0.5, ease: "expo.out", immediateRender: false }}, 141.4);
        tl.fromTo("#etitle .w", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.4, ease: "expo.out", stagger: 0.06, immediateRender: false }}, 141.6);
        tl.fromTo(["#einst", "#eurl"], {{ opacity: 0, y: 20 }}, {{ opacity: 1, y: 0, duration: 0.35, ease: "expo.out", stagger: 0.12, immediateRender: false }}, 142.1);
        cam(141.9, 3.0, {{ s: 0.84 }}, "sine.inOut");
        tl.fromTo("#fadeout", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.5, ease: "power2.in", immediateRender: false }}, 145.0);
""")

css("#fadeout { position: absolute; inset: 0; background: var(--bg); opacity: 0; }")
# grid patches instead of one giant grid
build(DUR)
p = os.path.join(ROOT, "src/index.html")
s = open(p).read()
s = s.replace('<div id="ovl"></div>', f'<div id="ovl"><div id="cloudbg"></div>{film_ovl}<div id="fadeout"></div></div>')
s = s.replace("%%JSEND%%", "")
patches = "".join(f'<div class="gpatch" style="left:{gx}px;top:{gy}px"></div>' for gx in range(-3000, 60000, 9000) for gy in (-3000, 3000, 9000))
s = s.replace('<div id="grid"></div>', patches)
s = s.replace("#grid { position: absolute; left: -6000px; top: -6000px; width: 20000px; height: 16000px;", ".gpatch { position: absolute; width: 9000px; height: 6000px;")
for i_ in ['id="rails"', 'id="a3b"', 'id="browser"', 'id="railscard"']:
    s = s.replace(i_, i_ + " data-layout-allow-overlap", 1)
open(p, "w").write("\n".join(line.rstrip() for line in s.split("\n")))
print("full built")
