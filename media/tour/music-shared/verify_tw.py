#!/usr/bin/env python3
"""Reads a "tired vs wired" cut's MIDI files back with an independent SMF parser
and checks them against its score.json and the video's own cue MIDI (named in
score.json "checks"): every TIRED/WIRED flip, every accent, the harmony, the
stop-time, the climax hit, the arc and the loop seam. Standard library only.

  python3 music-shared/verify_tw.py music-v7
"""

import json
import os
import struct
import sys

HERE = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "music-v7"))
failures = []


def check(ok, what):
    if not ok:
        failures.append(what)
    return ok


def read_smf(path):
    data = open(path, "rb").read()
    assert data[:4] == b"MThd"
    _, fmt, ntrk, ppq = struct.unpack(">IHHH", data[4:14])
    pos, tracks = 14, []
    for _ in range(ntrk):
        assert data[pos:pos + 4] == b"MTrk", path
        (length,) = struct.unpack(">I", data[pos + 4:pos + 8])
        body, pos = data[pos + 8:pos + 8 + length], pos + 8 + length
        i, tick, status, events = 0, 0, None, []
        while i < len(body):
            delta = 0
            while True:
                b = body[i]; i += 1
                delta = (delta << 7) | (b & 0x7F)
                if not b & 0x80:
                    break
            tick += delta
            if body[i] & 0x80:
                status = body[i]; i += 1
            if status == 0xFF:
                kind = body[i]; i += 1
                ln = 0
                while True:
                    b = body[i]; i += 1
                    ln = (ln << 7) | (b & 0x7F)
                    if not b & 0x80:
                        break
                events.append((tick, "meta", kind, body[i:i + ln])); i += ln
            else:
                hi = status & 0xF0
                n = 1 if hi in (0xC0, 0xD0) else 2
                events.append((tick, "midi", status, tuple(body[i:i + n]))); i += n
        tracks.append(events)
    return fmt, ppq, tracks


def notes_of(events, ppq):
    on, out = {}, []
    for tick, kind, status, d in events:
        if kind != "midi":
            continue
        hi, ch = status & 0xF0, status & 0x0F
        if hi == 0x90 and d[1] > 0:
            on[(ch, d[0])] = (tick, d[1])
        elif hi == 0x80 or (hi == 0x90 and d[1] == 0):
            t0, vel = on.pop((ch, d[0]))
            out.append([t0 / ppq, d[0], vel, (tick - t0) / ppq, ch])
    check(not on, "hanging note-ons: %r" % on)
    return sorted(out)


def slug(s):
    import re
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


score = json.load(open(os.path.join(HERE, "score.json")))
C = score["checks"]
L = score["lengthBeats"]
WIRED, TIRED = score["wiredParts"], score["tiredParts"]
spans = [(h["from"], h["to"], h["chord"]) for h in score["harmony"]]
PCS = {"Cm9": {0, 3, 7, 10, 2, 5}, "F13": {5, 9, 0, 3, 7, 2}, "Abmaj7#11": {8, 0, 3, 7, 2, 10},
       "G7alt": {7, 11, 2, 5, 8, 3}, "Fm9": {5, 8, 0, 3, 7}, "Bb13": {10, 2, 5, 8, 0, 7},
       "Ebmaj9": {3, 7, 10, 2, 5}, "Cm6/9": {0, 3, 7, 9, 2}}


def chord_at(t):
    for a, b, c in spans:
        if a - 1e-9 <= t < b - 1e-9:
            return c
    return spans[0][2]


# ---- 1. every per-part file matches score.json ----------------------------------
back = {}
for i, t in enumerate(score["tracks"], 1):
    path = os.path.join(HERE, "midi", f"{i:02d}-{slug(t['name'])}.mid")
    fmt, ppq, tracks = read_smf(path)
    check(fmt == 0 and len(tracks) == 1, f"{path}: type 0, one track")
    metas = {(k, bytes(d)) for _, kind, k, d in tracks[0] if kind == "meta"}
    check((0x51, (500000).to_bytes(3, "big")) in metas, f"{t['name']}: tempo 120 BPM")
    check((0x58, bytes([4, 2, 24, 8])) in metas, f"{t['name']}: 4/4")
    got = notes_of(tracks[0], ppq)
    back[t["id"]] = got
    want = sorted(t["notes"])
    check(len(got) == len(want), f"{t['name']}: {len(got)} notes read back, {len(want)} written")
    for g, w in zip(got, want):
        if not (abs(g[0] - w[0]) < 1e-6 and g[1] == w[1] and g[2] == w[2] and abs(g[3] - w[3]) < 1.5 / ppq and g[4] == t["ch"]):
            check(False, f"{t['name']}: {g} != {w}")
            break

combined = [f for f in os.listdir(os.path.join(HERE, "midi")) if not f[:2].isdigit()]
fmt, ppq, tracks = read_smf(os.path.join(HERE, "midi", combined[0]))
check(fmt == 1 and len(tracks) == 1 + len(score["tracks"]), "combined: conductor + one track per part")
markers = [(tick / ppq, bytes(d).decode()) for tick, kind, k, d in tracks[0] if kind == "meta" and k == 0x06]
check(markers == [(c["beat"], c["name"]) for c in score["cues"]], "combined markers match the cue list")
for k, t in enumerate(score["tracks"], 1):
    check(len(notes_of(tracks[k], ppq)) == len(t["notes"]), f"combined {t['name']} note count")

for pid, ns in back.items():
    for n in ns:
        check(0 <= n[0] < L and n[0] + n[3] <= L + 1e-6, f"{pid}: note outside 0..{L}: {n}")
        check(abs(n[0] * 4 - round(n[0] * 4)) < 1e-9, f"{pid}: off the 16th grid: {n}")
RANGES = {"bass": (28, 60), "sub": (23, 36), "keys": (52, 72), "horn": (55, 86), "brass": (40, 80), "vibes": (53, 89),
          "tkeys": (40, 80), "thorn": (50, 66), "drone": (28, 48)}
for pid, (lo, hi) in RANGES.items():
    check(all(lo <= n[1] <= hi for n in back[pid]), f"{pid}: pitches outside {lo}-{hi}")


def onsets(pid):
    return {n[0] for n in back[pid]}


def sounding_after(pids, t):
    return [(p, n) for p in pids for n in back[p] if n[0] < t - 1e-9 and n[0] + n[3] > t + 1e-9]


# ---- 2. the flips, from the video's own cue MIDI ----------------------------------
fmt, cppq, ctr = read_smf(os.path.join(HERE, C["cueMidi"]))
cue = sorted((n[0], n[1]) for tr in ctr for n in notes_of(tr, cppq))
flips = [(b, "TIRED" if p == 48 else "WIRED") for b, p in cue if p in (48, 50)]
accents = [b for b, p in cue if p == 52]
check(len(flips) == C["flips"], f"{C['flips']} flips in the cue MIDI, found {len(flips)}")
check([(s["from"], s["state"]) for s in score["segments"]] == flips, "the score's segments are exactly the cue MIDI's flips")
flip_report = []
ends = [b for b, _ in flips[1:]] + [L]
for (b, state), end in zip(flips, ends):
    if state == "WIRED":
        need = ["impact", "crash", "brass", "kick", "keys", "bass"]
        mine, other = WIRED, TIRED
    else:
        need = ["thud", "tkeys", "drone", "tick"]
        mine, other = TIRED, WIRED
    missing = [p for p in need if b not in onsets(p)]
    check(not missing, f"{state} flip at {b / 2:.2f} s: no onset exactly on the beat for {missing}")
    ring = sounding_after(other, b)
    check(not ring, f"{state} flip at {b / 2:.2f} s: the other world still sounds across it: {ring[:3]}")
    stray = [(p, x) for p in other for x in onsets(p) if b <= x < end]
    check(not stray, f"{state} segment {b / 2:.2f}-{end / 2:.2f} s: the other world plays inside it: {stray[:3]}")
    flip_report.append((b, state, [p for p in need if b in onsets(p)]))

# ---- 3. accents: every E3 in the cue MIDI has an onset within a 16th ---------------
HIT = WIRED + TIRED
for b in accents:
    who = [p for p in HIT if any(abs(x - b) <= 0.125 + 1e-9 for x in onsets(p)) and p not in ("hat", "shaker", "tick")]
    check(bool(who), f"accent at {b / 2:.2f} s has no hit within a 16th")

# ---- 4. harmony audit -----------------------------------------------------------------
bad = []
for pid in ["keys", "brass", "tkeys", "vibes"]:
    for n in back[pid]:
        c = chord_at(n[0])
        nxt = chord_at(n[0] + 0.5)
        if n[1] % 12 not in PCS[c] and n[1] % 12 not in PCS[nxt]:
            bad.append((pid, n[0], n[1], c))
for n in back["bass"]:
    c, nxt = chord_at(n[0]), chord_at(n[0] + 0.25)
    if n[1] % 12 not in PCS[c] and n[1] % 12 not in PCS[nxt]:
        near = chord_at(n[0] + 0.25) != c
        if not near:
            bad.append(("bass", n[0], n[1], c))
check(not bad, f"notes outside their chord: {bad[:6]}")
SCALE = {0, 2, 3, 5, 7, 9, 10, 8, 11}                  # C Dorian, plus Ab and B from the loop's back half
for pid in ["horn", "thorn"]:
    check(all(n[1] % 12 in SCALE for n in back[pid]), f"{pid}: notes outside C Dorian (+Ab, B)")

# ---- 5. stop-time and the ending --------------------------------------------------------
c2, u, e = C["closing"], C["useRuby"], C["endCard"]
STOP = [c2, c2 + 0.75, c2 + 1.5, c2 + 2.5]
for b in STOP:
    check(b in onsets("brass") and b in onsets("kick"), f"stop-time hit at {b / 2:.3f} s")
for pid in ["hat", "ohat", "ride", "shaker", "rim", "horn", "vibes"]:
    check(not [x for x in onsets(pid) if c2 <= x < u], f"stop-time: {pid} plays between the hits")
check(sorted(x for x in onsets("snare") if c2 <= x < u) == [u - 0.5, u - 0.25], "stop-time: only the pickup snare")
check(not [p for p in back if p != "riser" and [x for x in onsets(p) if u - 0.75 <= x < u - 0.5]], "stop-time: a silent gap before the pickup")
check(not sounding_after([p for p in WIRED if p not in ("crash", "impact")], c2 + 3.25), "stop-time: nothing but cymbal and impact tails between the last hit and the pickup")
for p in ["impact", "crash", "brass", "kick", "bass"]:
    check(u in onsets(p), f"Use Ruby. ({u / 2:g} s): {p}")
check(e in onsets("keys") and chord_at(e) == "Cm6/9", f"end card on Cm6/9 at {e / 2:g} s")
h = C["climaxHit"]
for p in ["impact", "crash", "brass", "kick", "vibes"]:
    check(h in onsets(p), f"climax hit ({h / 2:g} s): {p}")

# ---- 6. the loop seam ------------------------------------------------------------------------
check(all(n[0] + n[3] <= L + 1e-9 for ns in back.values() for n in ns), "nothing rings past the loop point")
check(chord_at(L - 0.25) == "Cm6/9" and chord_at(0) == "Abmaj7#11", "Cm6/9 hands to the TIRED Abmaj7#11 of bar 1 (common tones C, Eb, G, D)")

# ---- report --------------------------------------------------------------------------------------
print(f"Flips from {os.path.normpath(os.path.join(os.path.basename(HERE), C['cueMidi']))} (C3 TIRED, D3 WIRED) against the score:")
for b, state, who in flip_report:
    print(f"  {b / 2:6.2f} s  beat {b:6.2f}  {state}  0 ms  on the beat: {', '.join(who)}")
print("\nEnergy per 2 s (sum of onset velocities / 100), T = TIRED, W = WIRED:")
for bar in range(1, L // 4 + 1):
    a, b = (bar - 1) * 4, bar * 4
    e = sum(n[2] for ns in back.values() for n in ns if a <= n[0] < b) / 100
    states = "".join(s["state"][0] for s in score["segments"] if s["from"] < b and s["to"] > a)
    sec = next((s["name"] for s in reversed(score["sections"]) if s["beat"] <= a), "")
    print(f"  {a / 2:5.0f} s {states:<4} {e:6.1f} {'#' * int(e / 3):<44} {sec}")
if failures:
    print(f"\n{len(failures)} FAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print(f"\nall checks passed: {sum(len(v) for v in back.values())} notes read back from {len(back)} part files; "
      f"{len(flips)} flips, {len(accents)} accents checked")
