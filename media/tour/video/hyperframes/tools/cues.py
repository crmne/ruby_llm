# v7 cue sheet + cue MIDI (same format as v6: markers track, notes C3 = TIRED, D3 = WIRED snap, E3 = accent)
import os, struct
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders")
DUR, BPM, PPQ = 152.0, 120, 480

def bb(t):
    bar = int(t // 2) + 1
    beat = (t % 2) / 0.5 + 1
    return f"{bar}.{beat:g}"

SECTIONS = [
    ("01 First ask", 0.0, "Raw request, implode into chat.ask; the answer takes the name first.output and lands on it"),
    ("02 Conversation", 8.5, "Manual history, vacuum into two chat.ask lines"),
    ("03 Streaming into Rails", 14.5, "Typed events squeeze into chat.ask do |chunk|; print pulses per chunk; the block lands in ChatStreamJob, the job builds around it"),
    ("04 Files", 26.0, "Base64 world shatters; chat.ask with: on two lines, three variants"),
    ("05 Tools", 35.0, "Hand-rolled tool loop folds; quicker walkthrough; demo thread"),
    ("06 MCP", 47.0, "Manual client vacuums into RubyLLM::MCP; GitHub, Notion, Atlassian, Sentry"),
    ("07 Structured output", 60.0, "Schema world shatters; values picked out of a messy product.txt into the Hash"),
    ("08 Judge", 71.0, "Ticket hand-off; model, question, verdict bars"),
    ("09 Agent with approval", 78.0, "Tool and job files, approval click, push into the model id"),
    ("10 Providers (build)", 88.0, "Each provider's API and response shape next to its RubyLLM line, three squeezes, the three lines above the logo wall"),
    ("11 speak + transcribe", 103.5, "Two curls, snap, one voice note plays then transcribes in place"),
    ("12 paint + animate", 110.0, "Two curls, snap, painted panda + longer animate clip"),
    ("13 embed + rerank", 118.0, "Two curls, snap, the vector's numbers; five documents sorted by score"),
    ("14 ocr + moderate", 125.5, "Two curls, snap, PDF page scans into Markdown; flagged? false"),
    ("15 Everything else (climax)", 132.0, "Dive out; a camera tour of twelve feature tiles, two at a time; at 140.5 the bento lands around RubyLLM"),
    ("16 Ending", 144.0, "Closing line, Use Ruby., end card"),
]
FLIPS = [
    (0.0, "TIRED", "TIRED: first ask (raw request)"), (4.0, "WIRED", "WIRED: snap RubyLLM.chat.ask"),
    (8.5, "TIRED", "TIRED: conversation (manual history)"), (11.5, "WIRED", "WIRED: snap chat.ask, chat.ask"),
    (14.5, "TIRED", "TIRED: streaming (typed events)"), (17.5, "WIRED", "WIRED: snap chat.ask do |chunk|"),
    (26.0, "TIRED", "TIRED: files (base64 content parts)"), (29.0, "WIRED", "WIRED: snap chat.ask with:"),
    (35.0, "TIRED", "TIRED: tools (JSON schema by hand)"), (38.5, "WIRED", "WIRED: snap RubyLLM::Tool"),
    (47.0, "TIRED", "TIRED: MCP (manual client)"), (50.5, "WIRED", "WIRED: snap RubyLLM::MCP"),
    (60.0, "TIRED", "TIRED: structured output (parse by hand)"), (63.5, "WIRED", "WIRED: snap with_schema"),
    (88.0, "TIRED", "TIRED: Anthropic curl"), (91.5, "WIRED", "WIRED: snap claude-opus-5-5"),
    (92.0, "TIRED", "TIRED: Gemini curl"), (95.0, "WIRED", "WIRED: snap gemini-3.8-flash"),
    (95.5, "TIRED", "TIRED: Bedrock boto3"), (98.5, "WIRED", "WIRED: snap provider: :bedrock"),
    (103.5, "TIRED", "TIRED: speech + transcription (curl)"), (106.0, "WIRED", "WIRED: snap RubyLLM.speak / RubyLLM.transcribe"),
    (110.0, "TIRED", "TIRED: image + video generation (curl, polling)"), (112.5, "WIRED", "WIRED: snap RubyLLM.paint / RubyLLM.animate"),
    (118.0, "TIRED", "TIRED: embeddings + rerank (curl)"), (120.5, "WIRED", "WIRED: snap RubyLLM.embed / RubyLLM.rerank"),
    (125.5, "TIRED", "TIRED: OCR + moderation"), (128.0, "WIRED", "WIRED: snap RubyLLM.ocr / RubyLLM.moderate"),
]
STRUCT = [(71.0, "WIRED: Judge (cut)"), (78.0, "WIRED: Agent (cut)"), (100.0, "WIRED: logo wall build"),
          (132.0, "WIRED: CLIMAX everything else"), (144.0, "WIRED: closing line (stop-time hit)"), (147.5, "WIRED: end card (final chord)")]
CUTS = [
    (7.5, "Whip: the answer flies to the manual code and squeezes into first.output there"),
    (14.0, "Prompt dives into the stream line"),
    (21.0, "Whip to Rails: haiku into the browser, block into chat_stream_job.rb"),
    (26.0, "Whip into files world (chips fly out of the chat)"),
    (35.0, "Whip into tools world"),
    (47.0, "Whip into MCP world"),
    (54.5, "Cut down to the server row (GitHub)"), (56.0, "Whip: Notion"), (57.0, "Whip: Atlassian"), (58.0, "Whip: Sentry"),
    (59.5, "Whip into the tilted structured-output world"),
    (71.0, "Whip to Judge, ticket travels"),
    (78.0, "Whip to Agent, ticket travels"), (81.0, "Push-in on approval"), (83.0, "Pull back to tool file"), (86.5, "Push into model id"),
    (87.5, "Whip into Anthropic world"), (92.0, "Whip to Gemini"), (95.5, "Whip to Bedrock"),
    (99.0, "The three RubyLLM lines, together above the wall"), (100.0, "Pull out to logo wall"),
    (103.0, "Whip to speak/transcribe"), (109.5, "Whip to paint/animate"), (117.5, "Whip to embed/rerank"), (125.0, "Whip to ocr/moderate"),
    (132.0, "Camera dives out; feature cards begin 132.8"),
    (144.0, "Punch-in to the closing line"), (146.0, "Use Ruby."), (147.5, "Pan down to end card"), (151.5, "Fade to background"), (152.0, "End (loops to 0)"),
]
ACCENTS = [
    (6.35, "Answer lifts off"), (13.4, "Next prompt pops"), (17.85, "haiku.rb terminal opens"), (18.25, "Haiku streams"),
    (22.0, "ChatStreamJob builds around the block"),
    (30.6, "with: variant 1"), (32.0, "with: variant 2"), (33.3, "with: variant 3"), (34.45, "Prompt pops for tools"),
    (39.25, "Walkthrough: class"), (39.85, "Walkthrough: RubyLLM::Tool"), (40.45, "Walkthrough: description"), (41.05, "Walkthrough: execute"), (41.75, "Walkthrough: with_tools"),
    (42.6, "Tool demo thread"), (54.85, "Title: Another server is three lines away."),
    (64.1, "product.txt"), (65.8, "Values picked out of the text"),
    (70.5, "Ticket pops"), (72.6, "model line"), (74.0, "urgent.probability 0.97"), (75.0, "frustration bars"),
    (82.5, "Approve click"), (101.3, "19 providers. One Ruby API."),
    (106.3, "Voice note appears"), (107.0, "Voice note plays"), (109.5, "Transcribed in place"), (112.85, "Panda painted"), (113.1, "Panda animates"),
    (121.0, "Vector numbers"), (122.6, "Rerank sorts by score"), (129.2, "PDF scans into Markdown"),
    (140.5, "Bento reveal around RubyLLM (the hit)"),
]

rows = []
for t, st, lab in FLIPS:
    rows.append((t, "Flip to " + st, lab.split(": ", 1)[1]))
for t, lab in STRUCT:
    rows.append((t, "Section", lab.split(": ", 1)[1]))
for t, lab in CUTS:
    rows.append((t, "Cut/camera", lab))
for t, lab in ACCENTS:
    rows.append((t, "Accent", lab))
rows.sort(key=lambda r: (r[0], r[1]))
for t, ty, _ in rows:
    if ty != "Accent":
        assert abs(t * 2 - round(t * 2)) < 1e-9, ("off beat", t, ty)
ends = [s[1] for s in SECTIONS[1:]] + [DUR]
o = ['# RubyLLM v8.3 "tired vs wired": cue sheet', "",
     "- **Tempo:** 120 BPM, 4/4. One beat = 0.5 s, one bar = 2.0 s.",
     f"- **Length:** {DUR:.1f} s = {int(DUR // 2)} bars. Loops to 0.0.",
     "- **Notation:** bar.beat is 1-based; 4.5 means halfway through beat 4.",
     "- **TIRED** = muffled, low-passed, dragging bed under the dark verbose code. **WIRED** = bright after each snap. Every WIRED flip is the compression hit. Timing is identical to v7.",
     "- Every flip, cut and section start sits on a beat. Accents are on-screen events to catch where the arrangement wants them.",
     "- **Files:** `rubyllm-tour-v8.3-cues.mid` (markers; notes C3 = TIRED, D3 = WIRED snap, E3 = accent), `rubyllm-tour-v8.3-silent.mp4`.",
     "", "## Sections", "", "| Section | Start (s) | Bar.beat | Bars | Picture |", "|---|---|---|---|---|"]
for (n, t, d), e in zip(SECTIONS, ends):
    o.append(f"| {n} | {t:.1f} | {bb(t)} | {(e - t) / 2:g} | {d} |")
o += ["", "Arc: 0 to 26 s sets up the pattern (three flips); 26 to 71 s is one flip per feature; 71 to 88 s stays WIRED (Judge, Agent); 88 to 103.5 s is the build, three flips about 3.5 s apart with each provider's RubyLLM line on screen; 103.5 to 132 s is four pairs; 132 s is the climax (feature cards); 144 s stop-time for the closing line; 147.5 s final chord.",
      "", "## Every flip, cut and accent", "", "| Time (s) | Bar.beat | Type | On screen |", "|---|---|---|---|"]
for t, ty, d in rows:
    o.append(f"| {t:.2f} | {bb(t)} | {ty} | {d} |")
os.makedirs(OUT, exist_ok=True)
open(os.path.join(OUT, "v8.3-cues.md"), "w").write("\n".join(o) + "\n")

def vlq(n):
    b = [n & 0x7F]
    n >>= 7
    while n:
        b.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(b)
def ticks(sec):
    return int(round(sec * BPM / 60 * PPQ))
def track(events):
    events.sort(key=lambda e: e[0])
    out, last = b"", 0
    for tk, d in events:
        out += vlq(tk - last) + d
        last = tk
    out += vlq(0) + b"\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(out)) + out
t1 = [(0, b"\xff\x03" + vlq(4) + b"Cues"), (0, b"\xff\x51\x03" + struct.pack(">I", 500000)[1:]), (0, b"\xff\x58\x04\x04\x02\x18\x08")]
t2 = [(0, b"\xff\x03" + vlq(9) + b"Cue notes")]
def marker(sec, text):
    tb = text.encode("utf-8")
    t1.append((ticks(sec), b"\xff\x06" + vlq(len(tb)) + tb))
def note(sec, n, vel=100):
    t2.append((ticks(sec), bytes([0x90, n, vel])))
    t2.append((ticks(sec) + PPQ // 4, bytes([0x80, n, 0])))
for t, st, lab in FLIPS:
    marker(t, lab)
    note(t, 48 if st == "TIRED" else 50)
for t, lab in STRUCT:
    marker(t, lab)
for t, lab in ACCENTS:
    marker(t, lab)
    note(t, 52, 80)
marker(DUR, "End (loop to 0)")
open(os.path.join(OUT, "rubyllm-tour-v8.3-cues.mid"), "wb").write(b"MThd" + struct.pack(">IHHH", 6, 1, 2, PPQ) + track(t1) + track(t2))
print("cues:", len(rows), "markers:", len(FLIPS) + len(STRUCT) + len(ACCENTS) + 1)
