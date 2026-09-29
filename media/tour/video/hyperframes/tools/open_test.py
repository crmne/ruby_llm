import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from film import *

GHOST_RESP = """HTTP/1.1 200 OK
content-type: application/json
openai-processing-ms: 612
x-request-id: req_8f2...
{ "id": "resp_67b7...", "object": "response", "status": "completed",
  "output": [{ "id": "msg_67b7...", "type": "message", "role": "assistant",
    "content": [{ "type": "output_text", "text": "...", "annotations": [] }] }],
  "usage": { "input_tokens": 36, "output_tokens": 87, "total_tokens": 123 } }
"""
GHOST_HIST = """history = [{ role: :user, content: "..." }]
history.concat(first.output)
history << { role: :user, content: "..." }
input: history, store: false
history.concat(second.output)
history << { role: :user, content: "..." }
"""
GHOST_SSE = """event: response.created
data: {"type":"response.created","response":{"id":"resp_67c9...","status":"in_progress"}}
event: response.output_item.added
event: response.content_part.added
event: response.output_text.delta
data: {"type":"response.output_text.delta","item_id":"msg_67c9...","delta":"Hi"}
event: response.output_text.done
event: response.content_part.done
event: response.output_item.done
event: response.completed
"""


RX, RY = 1900, 2350
TAGX, TAGY = 3120 + 15 * 21.6, 1260 + 10 * 56
TAGX0, TAGY0 = 300, 1905 + 2 * 64 + 14


def opening(T0=0.0, wide=True):
    global CIN
    """First ask, conversation, streaming into Rails. Returns end time."""
    t = T0
    warp([[0, 0], [6.9, 6.9], [6.9001, 7.4]])
    # --- world layout
    region("rA", -380, -150, 3160, 1880, GHOST_RESP, ghost_fs=22)
    region("rB", 2820, 950, 3160, 1880, GHOST_HIST, ghost_fs=22)
    region("rC", -380, 2720, 3160, 1810, GHOST_SSE, ghost_fs=22)
    code("bA", "b_ask", "shell", 0, 260, 44, 66, dark=True)
    code("bB", "b_convo", "ruby", 3120, 1260, 36, 56, dark=True)
    code("bC", "b_stream", "ruby", 0, 2960, 36, 54, dark=True)
    code("a1", "a_block1", "ruby", 300, 1760, 40, 60)
    html('<div class="bigtype" id="ans1" style="left:300px;top:1905px;width:1560px;font-size:50px;line-height:1.28"></div>')
    code("a2", "a_block2", "ruby", 300, 2110, 40, 60)
    html('<div class="bigtype" id="ans2" style="left:300px;top:2195px;width:1560px;font-size:50px;line-height:1.28"></div>')
    code("a3", "a_block3", "ruby", 300, 2420, 40, 60)
    html('<div class="bigtype" id="ho-prompt" style="left:300px;top:2400px;font-size:84px;white-space:nowrap;opacity:0">"Write a haiku about Ruby."</div>')
    html('<div class="bigtype" id="ho-out" style="left:300px;top:1905px;width:1560px;font-size:50px;line-height:1.28;opacity:0;color:#b30000">Under a sky full of stars, a small unicorn learned that kindness shines brighter than any horn.</div>')
    html('<div class="term" id="term" style="left:300px;top:2660px;width:1180px;height:400px;padding:0;overflow:hidden;opacity:0"><div class="tbar"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i><span>haiku.rb</span></div><div style="padding:28px 44px"><div style="color:#8ec07c;font-size:28px;margin-bottom:18px">$ ruby haiku.rb</div><div id="haiku" style="font-size:48px;line-height:1.45"></div></div></div>')
    css(".tbar { position: relative; height: 56px; display: flex; align-items: center; gap: 12px; padding: 0 22px; background: #2b2623; border-bottom: 1px solid #3a332e; } .tbar i { display: block; width: 16px; height: 16px; border-radius: 50%; } .tbar span { position: absolute; left: 0; right: 0; text-align: center; font-family: var(--sans); font-weight: 600; font-size: 24px; color: #b8ad9f; }")
    html('''<div class="panel" id="browser" style="left:3000px;top:2150px;width:1000px;height:820px;opacity:0">
  <div class="bar"><i></i><i></i><i></i><span style="margin-left:12px;flex:1;height:40px;border-radius:10px;background:#fff;border:2px solid var(--line);font-family:var(--mono);font-weight:400;font-size:22px;color:var(--muted);display:flex;align-items:center;padding:0 16px">localhost:3000/chats/1</span></div>
  <div style="height:76px;display:flex;align-items:center;justify-content:space-between;padding:0 30px;border-bottom:2px solid #efe8e4;font-family:var(--sans);font-weight:600;font-size:30px;color:var(--heading)">Chat 1<span id="turbo" style="font-family:var(--mono);font-weight:400;font-size:22px;color:#356b49;background:#eef2ea;padding:8px 16px;border-radius:999px">turbo stream</span></div>
  <div style="position:relative;padding:34px 30px">
    <div id="bq" style="margin-left:auto;width:max-content;font-family:var(--sans);font-size:30px;color:#fdf6f4;background:#b30000;padding:18px 26px;border-radius:24px 24px 8px 24px;opacity:0">Write a haiku about Ruby.</div>
    <div id="bb" style="margin-top:26px;display:flex;gap:18px;align-items:flex-start;opacity:0"><img class="ava" src="assets/logos/logo.svg" alt="" /><div id="bbt" style="font-family:var(--sans);font-size:34px;line-height:1.45;color:var(--text);padding:20px 26px;border-radius:8px 24px 24px 24px;background:#f6f1ee"></div></div>
  </div>
</div>''')
    rr = code("rails", "a_stream_job", "ruby", RX, RY, 32, 48)
    CW, CH = rr[2] + 80, rr[3] + 130
    CIN = (100 + 4 * 48 - 18, 24, CH - (100 + 8 * 48 + 18), 40 + 4 * 19.2 - 26)
    CIN = (round(CIN[0]), round(CIN[1]), round(CIN[2]), round(CIN[3]))
    html(f'<div class="panel" id="railscard" style="left:{rr[0]-40}px;top:{rr[1]-100}px;width:{rr[2]+80}px;height:{rr[3]+130}px;opacity:0;z-index:0"><div class="bar"><i></i><i></i><i></i>app/jobs/chat_stream_job.rb</div></div>')
    code("a3b", "a_block3", "ruby", RX, RY, 32, 48, extra_cls="shown", style="opacity:0")
    html('<div class="bigtype" id="ho-haiku" style="left:344px;top:2800px;width:1080px;font-size:48px;line-height:1.45;white-space:pre;opacity:0;font-family:var(--mono);font-weight:400;color:#ebe8dc">Blocks yield like spring rain,\nmethods bloom in quiet red,\njoy compiles itself.</div>')
    css("#railscard { z-index: 0 } #rails, #a3b { z-index: 1 } .cb.shown .t { opacity: 1; }")

    js(f"""
        // ======== OPENING ========
        camSet({{ x: 1200, y: 790, s: 0.69 }});
        tl.set(".cb.dark", {{ opacity: 1 }}, 0);
        // TIRED A: raw request floods the frame
        cam({t + 0.0}, 3.5, {{ s: 0.75, r: -0.8, y: 760 }}, "sine.inOut");
        mark("#bA", 1, 2, {t + 0.6}, 1.3, "auth headers, every request");
        mark("#bA", 8, 11, {t + 1.6}, 1.4, "dig the text out yourself");
        mark("#bA", 5, 5, {t + 2.6}, 0.8, "and the prompt");
        // SNAP 1 (WIRED at {t + 4.0})
        collapseRegion("#rA", 1044, 1820, {t + 3.5}, 0.5);
        compress("#bA", "#a1", {t + 3.55}, "implode", {{ match: "Write a one-sentence bedtime story about a unicorn.", dur: 0.45, seed: 3, shake: 9 }});
        cam({t + 4.45}, 0.9, {{ x: 1044, y: 1800, s: 1.12 }}, "power3.inOut");
        const e1 = stream("#ans1", "Under a sky full of stars, a small unicorn learned that kindness shines brighter than any horn.", {t + 4.95}, 0.075);
        cam({t + 5.35}, 1.65, {{ y: 1905, s: 0.97 }}, "sine.inOut");
        // HAND-OFF 1: the answer lifts off, flies to the manual-history code and squeezes into first.output there
        tl.set("#ho-out", {{ opacity: 1 }}, {t + 6.3});
        tl.set("#ans1", {{ opacity: 0 }}, {t + 6.3});
        tl.set("#ans1", {{ opacity: 1 }}, {t + 8.6});
        tl.fromTo("#ho-out", {{ color: "#2c2926", y: 0 }}, {{ color: "#b30000", y: -10, duration: 0.35, ease: "power2.out", immediateRender: false }}, {t + 6.3});
        tl.to("#ho-out", {{ x: {TAGX} - 300, y: {TAGY} - 1905 - 4, scaleX: {12 * 21.6 / 1560:.4f}, scaleY: {56 / 128:.4f}, transformOrigin: "0% 0%", duration: 0.75, ease: "power3.in" }}, {t + 7.0});
        tl.to("#ho-out", {{ opacity: 0, duration: 0.15 }}, {t + 7.62});
        hbox({TAGX}, {TAGY}, {12 * 21.6}, 56, {t + 7.7}, {t + 9.75});
        tl.fromTo('#bB .ln[data-ln="10"] .t', {{ color: "#d9d3c7" }}, {{ color: "#ffffff", duration: 0.2, yoyo: true, repeat: 1, immediateRender: false }}, {t + 7.72});
        cam({t + 7.0}, 0.9, {{ x: 4400, y: 1890, s: 0.69, r: 1.2 }}, "power4.inOut");
        whipBlur({t + 7.0}, 0.9, 8);
        // TIRED B: manual history
        cam({t + 8.0}, 2.5, {{ s: 0.73, r: 0.6 }}, "sine.inOut");
        mark("#bB", 10, 10, {t + 8.1}, 1.2, "carry every output yourself");
        mark("#bB", 1, 1, {t + 8.9}, 1.0, "you keep the history");
        mark("#bB", 13, 13, {t + 9.6}, 0.8, "resend all of it");
        // SNAP 2 (WIRED at {t + 11.0})
        collapseRegion("#rB", 624, 2140, {t + 10.5}, 0.5);
        compress("#bB", "#a2", {t + 10.55}, "vacuum", {{ match: "Tell me another.", from: "below", dur: 0.45, seed: 5, shake: 9 }});
        cam({t + 11.45}, 0.8, {{ x: 1044, y: 2010, s: 0.95 }}, "power3.inOut");
        stream("#ans2", "A small dragon found a lost star and carried it home before dawn.", {t + 11.8}, 0.07);
        // HAND-OFF 2: the next prompt drops into the streaming code
        tl.fromTo("#ho-prompt", {{ opacity: 0, scale: 1.3 }}, {{ opacity: 1, scale: 1, duration: 0.3, ease: "power4.out" }}, {t + 12.9});
        cam({t + 12.9}, 0.4, {{ y: 2330, s: 0.9 }}, "power2.out");
        cam({t + 13.5}, 0.65, {{ x: 1200, y: 3560, s: 0.69, r: -1.5 }}, "power3.inOut");
        tl.fromTo("#ho-prompt", {{ x: 0, y: 0, scale: 1 }}, {{ x: 40 * 21.6 - 300, y: 3014 - 2400 - 10, scale: 36 / 84, duration: 0.65, ease: "power3.inOut", immediateRender: false }}, {t + 13.5});
        tl.to("#ho-prompt", {{ opacity: 0, duration: 0.15 }}, {t + 14.12});
        hbox({40 * 21.6}, 3014, {27 * 21.6}, 54, {t + 14.12}, {t + 15.75});
        // TIRED C: streaming events by hand
        cam({t + 14.05}, 2.45, {{ s: 0.73, r: -0.8 }}, "sine.inOut");
        mark("#bC", 6, 12, {t + 14.5}, 1.2, "typed event classes");
        mark("#bC", 3, 4, {t + 15.2}, 0.9, "your own bookkeeping");
        mark("#bC", 8, 9, {t + 15.8}, 0.7, "assemble deltas yourself");
        // SNAP 3 (WIRED at {t + 17.0})
        collapseRegion("#rC", 864, 2490, {t + 16.5}, 0.5);
        compress("#bC", "#a3", {t + 16.55}, "fold", {{ match: "Write a haiku about Ruby.", dur: 0.45, seed: 11, shake: 9 }});
        // the block and its terminal, one frame
        cam({t + 17.45}, 0.8, {{ x: 890, y: 2760, s: 1.1 }}, "power3.inOut");
        tl.fromTo("#term", {{ opacity: 0, y: 40 }}, {{ opacity: 1, y: 0, duration: 0.4, ease: "expo.out", immediateRender: false }}, {t + 17.35});
        cam({t + 18.25}, 2.25, {{ s: 1.13 }}, "sine.inOut");
        stream("#haiku", "Blocks yield like spring rain,\\nmethods bloom in quiet red,\\njoy compiles itself.", {t + 17.75}, 0.14);
        // one pulse of `print chunk.content` per printed chunk
        streamLine('#a3 .ln[data-ln="1"]', 300, {2420 + 2 * 60}, {47 * 24}, {t + 17.6}, {t + 17.75}, 0.14, 13, {t + 19.75});
        // HAND-OFF 3: the haiku flies into the Rails chat, the block flies into the job
        tl.set("#ho-haiku", {{ opacity: 1 }}, {t + 20.5});
        tl.set("#haiku", {{ opacity: 0.25 }}, {t + 20.5});
        tl.fromTo("#ho-haiku", {{ x: 0, y: 0, scale: 1 }}, {{ x: 3140 - 344, y: 2470 - 2800, scale: 0.67, transformOrigin: "0% 0%", duration: 0.9, ease: "power3.inOut", immediateRender: false }}, {t + 20.5});
        tl.to("#ho-haiku", {{ opacity: 0, duration: 0.2 }}, {t + 21.4});
        // the block lands in its final place inside the job, then the job is built around it
        tl.set("#a3b", {{ opacity: 1 }}, {t + 20.5});
        tl.fromTo("#a3b", {{ x: 300 - {RX}, y: 2420 - {RY}, scale: 1.25 }}, {{ x: {4 * 19.2}, y: {4 * 48}, scale: 1, transformOrigin: "0% 0%", duration: 0.85, ease: "power3.inOut", immediateRender: false }}, {t + 20.5});
        tl.fromTo("#browser", {{ opacity: 0, rotationY: -30, transformPerspective: 1800, x: 200 }}, {{ opacity: 1, rotationY: 0, x: 0, duration: 0.8, ease: "expo.out", immediateRender: false }}, {t + 20.55});
        tl.set("#railscard", {{ clipPath: "inset({CIN[0]}px {CIN[1]}px {CIN[2]}px {CIN[3]}px round 18px)" }}, 0);
        tl.fromTo("#railscard", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.3, immediateRender: false }}, {t + 21.2});
        cam({t + 20.5}, 0.9, {{ x: 2930, y: 2560, s: 0.8, ry: -6 }}, "power3.inOut");
        whipBlur({t + 20.5}, 0.9, 6);
        tl.to(["#a1", "#a2", "#a3", "#ans1", "#ans2", "#term"], {{ opacity: 0, duration: 0.4 }}, {t + 20.7});
        tl.fromTo("#bq", {{ opacity: 0, y: 20 }}, {{ opacity: 1, y: 0, duration: 0.3, ease: "back.out(1.8)", immediateRender: false }}, {t + 20.9});
        // in place: ask becomes complete, print becomes the broadcast
        tl.to("#a3b .t", {{ opacity: 0, y: -12, duration: 0.2, stagger: 0.01, ease: "power2.in" }}, {t + 21.4});
        tl.fromTo('#rails .ln[data-ln="4"] .t, #rails .ln[data-ln="5"] .t, #rails .ln[data-ln="6"] .t, #rails .ln[data-ln="7"] .t', {{ opacity: 0, y: 12 }}, {{ opacity: 1, y: 0, duration: 0.25, stagger: 0.012, ease: "back.out(2)", immediateRender: false }}, {t + 21.5});
        // wrap it: the card opens out to the whole file, the class, perform and find build around the block
        tl.to("#railscard", {{ clipPath: "inset(0px 0px 0px 0px round 18px)", duration: 0.55, ease: "power3.inOut" }}, {t + 21.85});
        tl.fromTo('#rails .ln[data-ln="0"] .t, #rails .ln[data-ln="1"] .t, #rails .ln[data-ln="9"] .t, #rails .ln[data-ln="8"] .t', {{ opacity: 0, x: -24 }}, {{ opacity: 1, x: 0, duration: 0.3, stagger: 0.025, ease: "expo.out", immediateRender: false }}, {t + 21.95});
        tl.fromTo('#rails .ln[data-ln="2"] .t', {{ opacity: 0, x: -24 }}, {{ opacity: 1, x: 0, duration: 0.3, stagger: 0.03, ease: "expo.out", immediateRender: false }}, {t + 22.2});
        tl.fromTo("#bb", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.25, immediateRender: false }}, {t + 22.35});
        stream("#bbt", "Blocks yield like spring rain,\\nmethods bloom in quiet red,\\njoy compiles itself.", {t + 22.45}, 0.13);
        tl.fromTo("#turbo", {{ scale: 0.85 }}, {{ scale: 1.1, duration: 0.25, yoyo: true, repeat: 5, ease: "sine.inOut", immediateRender: false }}, {t + 22.45});
        // one pulse of the broadcast line per chunk that reaches the browser
        streamLine('#rails .ln[data-ln="6"]', {RX}, {RY + 7 * 48}, {rr[2]}, {t + 22.3}, {t + 22.45}, 0.13, 13, {t + 24.4});
        cam({t + 21.4}, 3.3, {{ s: 0.82, ry: -4 }}, "sine.inOut");
    """)
    if wide:
        js(f"""
        cam({t + 23.8}, 1.6, {{ x: 2250, y: 2380, s: 0.38, ry: 0 }}, "power2.inOut");
        cam({t + 25.4}, 2.6, {{ s: 0.36 }}, "sine.inOut");
        """)
    return t + 28.0


if __name__ == "__main__":
    end = opening(0.0)
    html_over = ""
    js("""
        tl.fromTo("#fadeout", { opacity: 0 }, { opacity: 1, duration: 0.6, ease: "power2.in", immediateRender: false }, 27.4);
    """)
    HTML.append("")
    import film
    film.CSS.append("#fadeout { position: absolute; inset: 0; background: var(--bg); opacity: 0; }")
    build(28)
    p = os.path.join(ROOT, "src/index.html")
    s = open(p).read().replace('<div id="ovl"></div>', '<div id="ovl"><div id="fadeout"></div></div>')
    open(p, "w").write(s)
