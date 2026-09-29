"""The "tired vs wired" score: the musical material and the arranger, shared by
every cut of the RubyLLM tour (music-v6, music-v7, ...).

What lives here is the music Carmine approved in v6 and must not drift between
cuts: the key, the home loop and its voicings, the motif and its answer, the
two worlds (TIRED and WIRED), the presets, the returns and the mix levels, and
how each is arranged onto a flip. Each cut's score.py holds only its timing
(flips, sections, accents, the ending) and calls run().

Standard library only.
"""

import argparse
import json
import math
import os
import random
import re
import shutil
import struct
import sys

VENDOR = "Carmine"
TEMPO = 120.0
STEP = 0.25
PPQ = 960

PKG = os.path.expanduser("~/.BitwigStudio/installed-packages/5.0")
ESS = PKG + "/Bitwig/Essentials/Presets"
LOPASS = ESS + "/Filter/Lo-Pass.bwpreset"

FX = [
    {"name": "Room", "preset": ESS + "/Reverb/Room Two.bwpreset", "db": -6.0, "color": [0.62, 0.58, 0.56]},
    {"name": "Hall", "preset": ESS + "/Reverb/Hall Two.bwpreset", "db": -5.0, "color": [0.70, 0.60, 0.62]},
    {"name": "Echo", "preset": ESS + "/Delay-2/3 16ths.bwpreset", "db": -7.0, "color": [0.66, 0.52, 0.55]},
]
MASTER = {"device": "Compressor+", "preset": ESS + "/Compressor+/Solid State Glue.bwpreset"}

DRUMS = [0.62, 0.56, 0.50]
LOW = [0.55, 0.08, 0.12]
HARM = [0.86, 0.46, 0.40]
TOP = [0.88, 0.14, 0.20]
FXC = [0.60, 0.60, 0.60]
DULL = [0.30, 0.30, 0.34]

# WIRED: bright, swung jazz-house. TIRED: the same world through a low-pass.
PARTS = [
    {"id": "kick",   "name": "Kick",     "preset": ESS + "/E-Kick/Clean Kick.bwpreset",            "ch": 9, "db": -5,  "pan": 0.5,  "sends": {},                         "color": DRUMS, "shuffle": True},
    {"id": "snare",  "name": "Snare",    "preset": ESS + "/E-Snare/Tacky Snare.bwpreset",          "ch": 9, "db": -10, "pan": 0.5,  "sends": {"Room": -12},              "color": DRUMS, "shuffle": True},
    {"id": "clap",   "name": "Clap",     "preset": ESS + "/E-Clap/Classic Clap.bwpreset",          "ch": 9, "db": -14, "pan": 0.5,  "sends": {"Room": -14},              "color": DRUMS},
    {"id": "hat",    "name": "Hat",      "preset": ESS + "/E-Hat/Combo Hat 1 Closed.bwpreset",     "ch": 9, "db": -16, "pan": 0.58, "sends": {"Room": -24},              "color": DRUMS, "shuffle": True},
    {"id": "ohat",   "name": "Open Hat", "preset": ESS + "/E-Hat/Combo Hat 1 Open.bwpreset",       "ch": 9, "db": -19, "pan": 0.44, "sends": {"Room": -20},              "color": DRUMS, "shuffle": True},
    {"id": "ride",   "name": "Ride",     "preset": ESS + "/E-Hat/Electro Ride Cymbal.bwpreset",    "ch": 9, "db": -21, "pan": 0.62, "sends": {"Room": -18},              "color": DRUMS, "shuffle": True},
    {"id": "shaker", "name": "Shaker",   "preset": ESS + "/E-Hat/Shaker 1.bwpreset",               "ch": 9, "db": -21, "pan": 0.38, "sends": {"Room": -20},              "color": DRUMS, "shuffle": True},
    {"id": "rim",    "name": "Rim",      "preset": PKG + "/Bitwig/Layered Instruments/Instrument Layer/SoftFocus Rim.bwpreset", "ch": 9, "db": -18, "pan": 0.42, "sends": {"Room": -16}, "color": DRUMS, "shuffle": True},
    {"id": "crash",  "name": "Crash",    "preset": ESS + "/Phase-4/PH4 Cymbal One.bwpreset",       "ch": 8, "db": -17, "pan": 0.52, "sends": {"Hall": -18},              "color": DRUMS},
    {"id": "bass",   "name": "Bass",     "preset": PKG + "/Bitwig/Bass and Guitar/Acoustic Bass Short.bwpreset", "ch": 0, "db": -6, "pan": 0.5, "sends": {"Room": -22},     "color": LOW, "shuffle": True},
    {"id": "sub",    "name": "Sub",      "preset": PKG + "/Bitwig/Polymerics/Sine Bass.bwpreset",  "ch": 1, "db": -13, "pan": 0.5,  "sends": {},                         "color": LOW},
    {"id": "keys",   "name": "Keys",     "preset": PKG + "/Bitwig/Electric Keys/Rhodes.bwpreset",  "ch": 2, "db": -9,  "pan": 0.47, "sends": {"Hall": -14, "Echo": -24}, "color": HARM, "shuffle": True},
    {"id": "horn",   "name": "Horn",     "preset": PKG + "/Orchestral Tools/Orchestral Brass/Orchestral Brass–Muted Staccato.bwpreset", "ch": 3, "db": -9, "pan": 0.54, "sends": {"Hall": -12, "Echo": -16}, "color": TOP, "shuffle": True},
    {"id": "brass",  "name": "Brass",    "preset": PKG + "/Orchestral Tools/Orchestral Brass/Orchestral Brass–Staccato.bwpreset", "ch": 4, "db": -12, "pan": 0.5, "sends": {"Hall": -12}, "color": TOP},
    {"id": "vibes",  "name": "Vibes",    "preset": PKG + "/Bitwig/Chromatic Percussion/Vibraphone.bwpreset", "ch": 5, "db": -14, "pan": 0.62, "sends": {"Hall": -12, "Echo": -14}, "color": TOP},
    {"id": "riser",  "name": "Riser",    "preset": ESS + "/Phase-4/Noise Riser.bwpreset",          "ch": 6, "db": -16, "pan": 0.5,  "sends": {"Hall": -10},              "color": FXC},
    {"id": "impact", "name": "Impact",   "preset": ESS + "/Polysynth/FX Impact.bwpreset",          "ch": 7, "db": -10, "pan": 0.5,  "sends": {"Hall": -9},               "color": FXC},
    {"id": "tkeys",  "name": "Tired Keys", "preset": PKG + "/Bitwig/Electric Keys/Rusty Rhodes.bwpreset", "ch": 10, "db": -12, "pan": 0.5, "sends": {"Hall": -14}, "color": DULL, "inserts": [LOPASS]},
    {"id": "thorn",  "name": "Tired Horn", "preset": PKG + "/Orchestral Tools/Orchestral Brass/Orchestral Brass–Muted Sustained.bwpreset", "ch": 11, "db": -13, "pan": 0.5, "sends": {"Hall": -12}, "color": DULL, "inserts": [LOPASS]},
    {"id": "drone",  "name": "Drone",    "preset": PKG + "/Bitwig/Perfect Drift/Synth/Unstable Warm Juno Pad.bwpreset", "ch": 12, "db": -16, "pan": 0.5, "sends": {"Hall": -16}, "color": DULL, "inserts": [LOPASS]},
    {"id": "thud",   "name": "Thud",     "preset": ESS + "/E-Kick/Low And Long Kick.bwpreset",     "ch": 13, "db": -9, "pan": 0.5,  "sends": {"Room": -18},              "color": DULL, "inserts": [LOPASS]},
    {"id": "tick",   "name": "Tick",     "preset": ESS + "/E-Hat/Low Hat Closed.bwpreset",         "ch": 13, "db": -19, "pan": 0.56, "sends": {"Room": -20},              "color": DULL, "inserts": [LOPASS]},
]
WIRED_PARTS = ["kick", "snare", "clap", "hat", "ohat", "ride", "shaker", "rim", "crash", "bass", "sub", "keys", "horn", "brass", "vibes", "impact"]
TIRED_PARTS = ["tkeys", "thorn", "drone", "thud", "tick"]
GROOVE = {"rate": "1/16", "shuffle": 24.0}   # the swing; only clips marked "shuffle" use it

KEY = {"kick": 36, "snare": 38, "clap": 39, "hat": 42, "ohat": 46, "ride": 51, "shaker": 70, "rim": 60,
       "crash": 60, "thud": 36, "tick": 42}
RISER_KEY = 48                            # C

# ---------------------------------------------------------------------------
# Harmony: C Dorian with jazz extensions. Rootless Rhodes voicings that move by
# step: Cm9 (Bb D Eb G), F13 (A D Eb G), Abmaj7#11 (C D Eb G),
# G7b9b13 (B Eb F Ab), then back to Cm9: every voice moves a half or whole step.
# ---------------------------------------------------------------------------
CHORDS = {
    "Cm9":       {"root": 36, "keys": [58, 62, 63, 67], "pcs": {0, 3, 7, 10, 2, 5}},
    "F13":       {"root": 41, "keys": [57, 62, 63, 67], "pcs": {5, 9, 0, 3, 7, 2}},
    "Abmaj7#11": {"root": 44, "keys": [60, 62, 63, 67], "pcs": {8, 0, 3, 7, 2, 10}},
    "G7alt":     {"root": 43, "keys": [59, 63, 65, 68], "pcs": {7, 11, 2, 5, 8, 3}},
    "Fm9":       {"root": 41, "keys": [56, 60, 63, 67], "pcs": {5, 8, 0, 3, 7}},
    "Bb13":      {"root": 46, "keys": [56, 60, 62, 67], "pcs": {10, 2, 5, 8, 0, 7}},
    "Ebmaj9":    {"root": 39, "keys": [55, 58, 62, 65], "pcs": {3, 7, 10, 2, 5}},
    "Cm6/9":     {"root": 36, "keys": [57, 62, 63, 67], "pcs": {0, 3, 7, 9, 2}},
}
HOME = ["Cm9", "F13", "Abmaj7#11", "G7alt"]
JUDGE = ["Fm9", "Bb13", "Ebmaj9", "Abmaj7#11"]
LOOPS = {"home": HOME, "judge": JUDGE}

# The horn motif: a call that climbs G Bb C Eb and leans on D (the 13th of F13),
# answered with C A (A natural: the Dorian colour); its answer, in the same
# rhythm, over the other half of the loop. (offset, pitch, length)
CALL = [(0.0, 67, 0.375), (0.5, 70, 0.25), (0.75, 72, 0.5), (1.5, 75, 0.25), (1.75, 74, 0.75), (3.0, 72, 0.25), (3.25, 69, 0.5)]
ANSWER = [(0.0, 72, 0.375), (0.5, 74, 0.25), (0.75, 75, 0.5), (1.5, 79, 0.25), (1.75, 77, 0.75), (3.0, 75, 0.25), (3.25, 71, 0.5)]
CALL_JUDGE = [(o, p + 5, d) for o, p, d in CALL[:5]] + [(3.0, 77, 0.25), (3.25, 74, 0.5)]   # over Fm9 / Bb13
LAST_CALL = [(0.0, 67, 0.375), (0.5, 69, 0.25), (0.75, 72, 0.5), (1.5, 75, 0.25), (1.75, 74, 3.0)]   # the Dorian A for the last call
PHRASES = {"call": CALL, "answer": ANSWER}


def sec(t):
    return round(t * TEMPO / 60 / STEP) * STEP


def pos(beat):
    bar = int(beat // 4) + 1
    rest = beat - (bar - 1) * 4
    return f"{bar}.{int(rest) + 1}.{int(round((rest - int(rest)) / 0.25)) + 1}"


class Film:
    """One cut's timing, read from its score.py module."""

    def __init__(self, cut):
        self.cut = cut
        self.total = cut.BARS * 4
        self.segs = []
        for i, (t, state, label) in enumerate(cut.FLIPS):
            a = sec(t)
            b = sec(cut.FLIPS[i + 1][0]) if i + 1 < len(cut.FLIPS) else self.total
            self.segs.append({"from": a, "to": b, "state": state, "label": label})
        e = cut.ENDING
        self.climax = sec(e["climax"])
        self.testimonials = sec(e["testimonials"]) if e.get("testimonials") is not None else None
        whole = lambda x: int(x) if float(x).is_integer() else x   # noqa: E731  (keeps score.json stable across cuts)
        self.closing = whole(sec(e["closing"]))
        self.use_ruby = whole(sec(e["use_ruby"]))
        self.end_card = whole(sec(e["end_card"]))


class Harmony:
    def __init__(self, total):
        self.spans = []                    # [start, end, chord]
        self.total = total

    def put(self, a, b, chord):
        if b > a:
            self.spans.append([a, b, chord])

    def loop(self, a, b, chords, every=2.0):
        t, i = a, 0
        while t < b - 1e-9:
            self.put(t, min(b, t + every), chords[i % len(chords)])
            t += every
            i += 1

    def at(self, t):
        for a, b, c in self.spans:
            if a - 1e-9 <= t < b - 1e-9:
                return c
        return self.spans[-1][2] if t >= self.total else self.spans[0][2]

    def next_after(self, t):
        cur = None
        for a, b, c in sorted(self.spans):
            if a - 1e-9 <= t < b - 1e-9:
                cur = (a, b, c)
        if not cur:
            return None, None
        for a, b, c in sorted(self.spans):
            if abs(a - cur[1]) < 1e-9:
                return a, c
        return cur[1], self.at(0.0)          # the loop wraps into bar 1


def plan_harmony(F):
    H = Harmony(F.total)
    for s in F.segs:
        a, b = s["from"], s["to"]
        if s["state"] == "TIRED":
            mid = a + math.ceil((b - a) / 2)
            H.put(a, mid, "Abmaj7#11")         # the back half of the loop, slowed: it drags toward the snap
            H.put(mid, b, "G7alt")
            continue
        spec = F.cut.WIRED_PLAN.get(a / 2, {"style": "snap", "level": 0})   # one-beat snaps: the home loop
        if spec.get("ending"):                 # the last WIRED stretch runs to the end
            c1 = F.testimonials if F.testimonials is not None else float(F.closing)
            H.loop(a, F.climax, HOME)
            H.loop(F.climax, c1, HOME)
            if F.testimonials is not None:
                H.loop(F.testimonials, float(F.closing), HOME, every=4.0)
            H.put(F.closing, F.closing + 2.5, "Abmaj7#11")
            H.put(F.closing + 2.5, F.use_ruby, "G7alt")
            H.put(F.use_ruby, F.end_card, "Cm9")
            H.put(F.end_card, F.total, "Cm6/9")
            continue
        subs = sub_sections(spec, a, b)
        for pa, pb, _, _, loop in subs:
            H.loop(pa, pb, LOOPS[loop])
    H.spans.sort()
    return H


def sub_sections(spec, a, b):
    """A WIRED stretch, split where the picture changes section without a flip."""
    marks = [(a, spec["style"], spec["level"], spec.get("loop", "home"))]
    for t, st, lv, loop in spec.get("subs", []):
        marks.append((sec(t), st, lv, loop))
    out = []
    for i, (t, st, lv, loop) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else b
        out.append((t, end, st, lv, loop))
    return out


class Score:
    def __init__(self, F, H):
        self.F, self.H = F, H
        self.total = F.total
        self.notes = {p["id"]: [] for p in PARTS}
        self.rng = random.Random(20260928)

    def add(self, part, start, pitch, vel, dur, until=None):
        start = round(start / STEP) * STEP
        if until is not None:
            dur = min(dur, until - start)
        if dur <= 0.01 or start < 0 or start >= self.total:
            return
        vel = int(max(1, min(127, round(vel))))
        while part == "vibes" and pitch > 89:                 # a vibraphone tops out at F6
            pitch -= 12
        self.notes[part].append([start, int(pitch), vel, round(min(dur, self.total - start), 4)])

    def j(self, v, amount=4):
        return v + self.rng.randint(-amount, amount)

    def cut(self, parts, at):
        for p in parts:
            for n in self.notes[p]:
                if n[0] < at < n[0] + n[3]:
                    n[3] = round(at - n[0], 4)

    def clear(self, parts, a, b):
        for p in parts:
            self.notes[p] = [n for n in self.notes[p] if not (a - 1e-9 <= n[0] < b - 1e-9)]

    def chord(self, part, t, name, vel, dur, up=0, until=None, root=False):
        ps = [p + up for p in CHORDS[name]["keys"]]
        if root:
            r = CHORDS[name]["root"]
            ps = [r + 12 if r + 12 < 52 else r] + ps
        for p in ps:
            self.add(part, t, p, self.j(vel, 3), dur, until)

    # ---- WIRED building blocks (patterns relative to the anchor) -------------
    def drums(self, a, b, style, level):
        t = a
        while t < b - 1e-9:
            for dt, part, key, vel, dur in self.bar_pattern(style, level):
                if t + dt < b - 1e-9:
                    self.add(part, t + dt, key, self.j(vel, 3), dur, b)
            t += 4

    def bar_pattern(self, style, level):
        K = KEY
        ev = []
        hat_acc = [30, 16, 62, 22]
        if style == "house":
            ev += [(x, "kick", K["kick"], 112 if x in (0, 2) else 106, 0.25) for x in (0, 1, 2, 3)]
            ev += [(x, "snare", K["snare"], 90, 0.25) for x in (1, 3)]
            if level >= 3:
                ev += [(x, "clap", K["clap"], 92, 0.25) for x in (1, 3)]
        elif style == "bb":
            ev += [(0, "kick", K["kick"], 114, 0.25), (1.75, "kick", K["kick"], 96, 0.25), (2.5, "kick", K["kick"], 104, 0.25)]
            ev += [(1, "snare", K["snare"], 96, 0.25), (3, "snare", K["snare"], 98, 0.25),
                   (2.25, "snare", K["snare"], 40, 0.2), (3.75, "snare", K["snare"], 46, 0.2)]
            if level >= 3:
                ev += [(3, "clap", K["clap"], 88, 0.25)]
        elif style == "light":
            ev += [(0, "kick", K["kick"], 72, 0.25), (2.5, "kick", K["kick"], 62, 0.25)]
            ev += [(x, "rim", K["rim"], 66, 0.2) for x in (1, 3)]
            ev += [(x * 0.5, "hat", K["hat"], [34, 20][x % 2], 0.1) for x in range(8)]
            ev += [(x * 0.25, "shaker", K["shaker"], [30, 16, 38, 18][x % 4], 0.1) for x in range(16)]
            return ev
        for k in range(16):
            v = hat_acc[k % 4]
            if level >= 3 and k % 4 == 2:
                continue                                   # the open hat takes the "and"
            ev.append((k * 0.25, "hat", K["hat"], v, 0.1))
        if level >= 3:
            ev += [(x + 0.5, "ohat", K["ohat"], 70, 0.4) for x in range(4)]
        if level >= 2:
            ev += [(x * 0.25, "shaker", K["shaker"], [34, 18, 44, 20][x % 4], 0.1) for x in range(16)]
            ev += [(0.75, "rim", K["rim"], 56, 0.2), (2.75, "rim", K["rim"], 50, 0.2)]
        if level >= 4:
            ev += [(x * 0.5, "ride", K["ride"], 64 if x % 2 == 0 else 44, 0.4) for x in range(8)]
        return ev

    def bass(self, a, b, style):
        H = self.H
        t = a
        while t < b - 1e-9:
            c = H.at(t)
            r = CHORDS[c]["root"]
            nxt, nc = H.next_after(t)
            span_end = min(b, nxt if nxt is not None else b)
            fifth = 12 if c == "G7alt" else 7
            if style == "light":
                pat = [(0, 0, 1.0, 0), (1.5, fifth, 0.5, -10), (2.5, 0, 0.75, -6)]
            elif style == "bb":
                pat = [(0, 0, 0.5, 0), (0.75, 0, 0.25, -12), (1.25, fifth, 0.25, -10)]
            else:
                pat = [(0, 0, 0.375, 0), (0.75, 12, 0.25, -14), (1.25, fifth, 0.25, -10)]
            for dt, iv, d, dv in pat:
                if t + dt < span_end - 1e-9:
                    self.add("bass", t + dt, r + iv, self.j(100 + dv, 3), d, span_end)
            # a chromatic approach on the last 16th into the next chord
            if nxt is not None and nxt < b + 1e-9 and nxt - t >= 2 - 1e-9 and nc != c and style != "light":
                n = CHORDS[nc]["root"]
                ap = n - 1 if n > r else n + 1
                if ap == r:
                    ap = r + fifth
                self.add("bass", nxt - 0.25, ap, self.j(90, 3), 0.25)
            if style != "light":
                self.add("sub", t, r - 12, 86, min(1.75, span_end - t))
            t = span_end

    def keys(self, a, b, style, vel=78):
        """Rhodes comping: a hit on the anchor, a ghost on the "a" of 1, and the next
        chord pushed an 8th early (a 16th later in the broken beat)."""
        H = self.H
        self.chord("keys", a, H.at(a), vel, 0.75, until=b)
        t = a
        while t < b - 1e-9:
            c = H.at(t)
            nxt, nc = H.next_after(t)
            end = min(b, nxt if nxt is not None else b)
            if style == "light":
                if t > a:
                    self.chord("keys", t, c, vel - 8, end - t - 0.25, until=b)
                t = end
                continue
            if t + 0.75 < end:
                self.chord("keys", t + 0.75, c, vel - 18, 0.25, until=b)
            push = 1.75 if style == "bb" else 1.5
            if nxt is not None and nxt < b - 1e-9 and nxt - t >= 2 - 1e-9:
                self.chord("keys", nxt - (2 - push), nc, vel - 4, 0.75, until=b)
            elif nxt is not None and nxt < b - 1e-9:
                self.chord("keys", nxt, nc, vel - 4, 0.75, until=b)
            t = end

    def horn(self, t, phrase, b, vel=96, up=0, vibes=False):
        for o, p, d in phrase:
            if t + o < b - 1e-9:
                self.add("horn", t + o, p + up, self.j(vel + (6 if o == 0 else 0), 3), d, b)
                if vibes:
                    self.add("vibes", t + o, p + 12, self.j(vel - 30, 2), d + 0.5, b)

    def snap(self, a, b, big=True):
        """The WIRED flip: everything lands on the beat."""
        c = self.H.at(a)
        self.add("impact", a, 36, 118 if big else 100, 3)
        self.add("crash", a, KEY["crash"], 112 if big else 96, 3)
        self.chord("brass", a, c, 112, 0.5, root=True, until=b)
        self.add("kick", a, KEY["kick"], 122, 0.25)

    def vibes_hit(self, t, vel=84, notes=2):
        c = self.H.at(t)
        top = sorted(p + 12 for p in CHORDS[c]["keys"])[-notes:]
        for p in top:
            self.add("vibes", t, p, self.j(vel, 2), 1.0)

    def brass_pushes(self, a, b, vel=96):
        t = a
        while t < b - 1e-9:
            nxt, nc = self.H.next_after(t)
            if nxt is not None and nxt < b - 1e-9 and nxt - t >= 2 - 1e-9:
                self.chord("brass", nxt - 0.5, nc, vel, 0.25, until=b)
            t = nxt if nxt is not None and nxt > t else b

    # ---- the two worlds -------------------------------------------------------
    def tired(self, a, b):
        n = b - a
        mid = a + math.ceil(n / 2)
        self.add("thud", a, KEY["thud"], 104, 0.5)
        if a + 4.25 < b:
            self.add("thud", a + 4.25, KEY["thud"], 86, 0.5)      # the heartbeat drags
        t = a
        while t < b - 1e-9:
            self.add("tick", t, KEY["tick"], 46, 0.1)
            t += 1
        for p in (31, 43):
            self.add("drone", a, p, 72, n)
        # the loop's back half, slow and rolled late: the drudgery version of the harmony
        ab, g7 = CHORDS["Abmaj7#11"]["keys"], CHORDS["G7alt"]["keys"]
        for i, p in enumerate(ab):
            self.add("tkeys", a + (0 if i < 2 else 0.25), p, 70 - i * 3, mid - a, b)
        self.add("tkeys", a, 44, 66, mid - a, b)
        for i, p in enumerate(g7):
            self.add("tkeys", mid + 0.25 + (0 if i < 2 else 0.25), p, 64 - i * 3, b - mid, b)
        self.add("tkeys", mid + 0.25, 43, 60, b - mid, b)
        # the wired motif as a tape slowed to half speed: half the tempo, an octave down
        for o, p, d in CALL[:5]:
            self.add("thorn", a + 0.5 + o * 2, p - 12, self.j(76, 3), d * 2 + 0.25, b)
        if n >= 4:
            self.add("riser", max(a, b - 3), RISER_KEY, 88, min(3, n))

    def wired_segment(self, s):
        a, b = s["from"], s["to"]
        n = b - a
        H = self.H
        if n <= 1:                                            # a one-beat snap
            self.snap(a, b)
            self.chord("keys", a, H.at(a), 86, 1, until=b)
            self.add("bass", a, CHORDS[H.at(a)]["root"], 106, 0.75)
            self.add("sub", a, CHORDS[H.at(a)]["root"] - 12, 90, 1)
            self.horn(a, CALL[:2], b, vel=104)
            self.add("snare", a + 0.5, KEY["snare"], 92, 0.2)
            return
        spec = self.F.cut.WIRED_PLAN[a / 2]
        self.snap(a, b)
        if spec.get("ending"):
            self.ending(a)
            return
        for pa, pb, st, lv, loopname in sub_sections(spec, a, b):
            loop = LOOPS[loopname]
            self.drums(pa, pb, st, lv)
            self.bass(pa, pb, st)
            self.keys(pa, pb, st)
            if pa > a:                                        # a section inside the stretch: a lighter snap
                self.add("crash", pa, KEY["crash"], 92, 3)
                self.chord("brass", pa, H.at(pa), 100, 0.5, root=True, until=pb)
                self.add("snare", pa - 0.5, KEY["snare"], 80, 0.2)
                self.add("snare", pa - 0.25, KEY["snare"], 96, 0.2)
            call = CALL_JUDGE if loop is JUDGE else CALL
            t = pa
            k = 0
            while t < pb - 1e-9:
                if k % 4 == 0:
                    self.horn(t, call, pb, up=0, vibes=lv >= 4)
                elif k % 4 == 1 and loop is HOME:
                    self.horn(t, ANSWER, pb, vibes=lv >= 4)
                elif k % 4 == 1:
                    self.horn(t, [(o, p + 5, d) for o, p, d in ANSWER[:5]], pb)
                t += 4
                k += 1
            if lv >= 4:
                self.brass_pushes(pa, pb)

    def ending(self, a):
        F, E = self.F, self.F.cut.ENDING
        c0, c2, c3 = F.climax, F.closing, F.end_card
        c1 = F.testimonials if F.testimonials is not None else c2
        # the last flip to the climax: level 4 and a riser
        self.drums(a, c0, "house", 4)
        self.bass(a, c0, "house")
        self.keys(a, c0, "house")
        self.horn(a, CALL, c0, vibes=True)
        self.brass_pushes(a, c0)
        self.add("riser", a + 2, RISER_KEY, 104, c0 - a - 2)
        self.add("snare", c0 - 1, KEY["snare"], 84, 0.2)
        for k in range(4):
            self.add("snare", c0 - 1 + k * 0.25, KEY["snare"], 84 + k * 10, 0.2)
        # the climax: every part
        self.snap(c0, c1)
        self.drums(c0, c1, "house", 5)
        self.bass(c0, c1, "house")
        self.keys(c0, c1, "house", vel=84)
        self.brass_pushes(c0, c1, vel=108)
        for off, phrase, vel in E["climax_horn"]:
            self.horn(c0 + off, PHRASES[phrase], c1, vel=vel, vibes=True)
        for t, what in E["climax_hits"]:
            hit = sec(t)
            if what == "hit":                                 # a picture hit inside the climax: the whole band
                self.add("impact", hit, 36, 120, 3)
            self.add("crash", hit, KEY["crash"], 104, 3)
            self.chord("brass", hit, self.H.at(hit), 108, 0.375, root=True)
            for k, p in enumerate([79, 82, 84, 87]):
                self.add("vibes", hit + 0.25 * k, p, 80 - k * 4, 1.0)
        if F.testimonials is not None:
            self.add("riser", c1 - 2, RISER_KEY, 70, 2)
            # testimonials: a light bed; the Rhodes breathes on a slower loop
            self.add("crash", c1, KEY["crash"], 70, 3)
            self.drums(c1, c2 - 1, "light", 1)
            self.bass(c1, c2 - 1, "light")
            self.keys(c1, c2 - 1, "light", vel=70)
            for q in E["quotes"]:
                self.vibes_hit(sec(q), 80, 3)
        self.add("riser", c2 - 1.5, RISER_KEY, 80, 1.5)        # the whip to the closing line
        # stop-time: "You don't need Python or JavaScript for AI."
        hits = [(c2, "Abmaj7#11", 118, 0.375), (c2 + 0.75, "Abmaj7#11", 102, 0.25), (c2 + 1.5, "Abmaj7#11", 112, 0.375),
                (c2 + 2.5, "G7alt", 118, 0.75)]
        for t, cn, v, d in hits:
            self.chord("brass", t, cn, v, d, root=True)
            self.chord("keys", t, cn, v - 30, d)
            self.add("kick", t, KEY["kick"], v, 0.25)
            self.add("bass", t, CHORDS[cn]["root"], v - 12, d)
            self.add("sub", t, CHORDS[cn]["root"] - 12, v - 24, d)
        self.add("impact", c2, 44, 100, 2)
        self.add("crash", c2, KEY["crash"], 100, 2)
        u = F.use_ruby
        self.add("snare", u - 0.5, KEY["snare"], 92, 0.2)
        self.add("snare", u - 0.25, KEY["snare"], 110, 0.2)
        # "Use Ruby.": the band on Cm9
        self.add("impact", u, 36, 127, 4)
        self.add("crash", u, KEY["crash"], 124, 4)
        self.chord("brass", u, "Cm9", 124, 1.5, root=True)
        self.chord("keys", u, "Cm9", 96, 2.75)
        self.add("kick", u, KEY["kick"], 124, 0.25)
        self.add("bass", u, 36, 116, 1.5)
        self.add("sub", u, 24, 104, 2.5)
        self.add("bass", u + 2.5, 39, 94, 0.25)                 # a walk-up into the end card
        self.add("bass", u + 2.75, 34, 98, 0.25)
        # the end card: Cm6/9, the horn's last call leaning on D, ringing into the loop
        e, T = c3, self.total
        self.chord("keys", e, "Cm6/9", 84, T - e - 0.25)
        self.add("bass", e, 36, 104, 2.0)
        self.add("sub", e, 24, 88, T - e - 0.25)
        self.add("impact", e, 36, 96, 4)
        self.chord("brass", e, "Cm6/9", 100, 0.75, root=True)
        self.horn(e + 0.5, LAST_CALL, T, vel=90, vibes=True)
        t = e
        while t < T - 1.5:
            self.add("ride", t, KEY["ride"], 50 if (t - e) % 1 == 0 else 34, 0.4)
            t += 0.5
        for k, p in enumerate([74, 79, 81, 86]):
            self.add("vibes", e + 3 + 0.25 * k, p, 60 - k * 4, 2.0)

    def accents(self):
        """kinds: vibes, brass (a stab and vibes), whip (an open hat and vibes),
        walk (the vibes climb through the chord, in order), skip (written with
        its section)."""
        walk = []
        for t, what, _, kind in self.F.cut.ACCENTS:
            b = sec(t)
            if kind == "skip":
                continue
            if kind == "walk":
                walk.append(b)
                continue
            seg = next(s for s in self.F.segs if s["from"] <= b < s["to"])
            if seg["state"] == "TIRED":
                self.add("tkeys", b, 79, 60, 0.5)
                continue
            if kind == "whip":
                self.add("ohat", b, KEY["ohat"], 84, 0.4)
            if kind == "brass":
                self.chord("brass", b, self.H.at(b), 104, 0.375, root=True)
            self.vibes_hit(b, 86)
        for k, b in enumerate(walk):
            self.add("vibes", b, sorted(p + 12 for p in CHORDS[self.H.at(b)]["keys"])[k % 4] + (12 if k >= 4 else 0), 82 + k * 2, 0.75)

    def whips(self):
        """The camera whips into each TIRED world: a one-beat swell, then the drag."""
        for s in self.F.segs:
            if s["state"] == "TIRED" and s["from"] > 0:
                prev = next(x for x in self.F.segs if x["to"] == s["from"])
                if prev["to"] - prev["from"] >= 4:
                    self.add("riser", s["from"] - 1, RISER_KEY, 66, 1)

    def finish(self):
        # the flips are hard cuts: nothing from the other world rings across one
        for s in self.F.segs:
            other = WIRED_PARTS if s["state"] == "TIRED" else TIRED_PARTS
            self.cut(other + (["riser"] if s["state"] == "WIRED" else []), s["from"])
            self.clear(other, s["from"], s["to"])
        for part, notes in self.notes.items():
            notes.sort(key=lambda n: (n[0], n[1], -n[2]))
            seen, out = set(), []
            for n in notes:
                if (n[0], n[1]) in seen:
                    continue
                seen.add((n[0], n[1]))
                out.append(n)
            by_key = {}
            for n in out:
                prev = by_key.get(n[1])
                if prev is not None and prev[0] + prev[3] > n[0]:
                    prev[3] = round(n[0] - prev[0], 4)
                by_key[n[1]] = n
            self.notes[part] = [n for n in out if n[3] > 0.01]


def compose(F):
    H = plan_harmony(F)
    s = Score(F, H)
    for seg in F.segs:
        if seg["state"] == "TIRED":
            s.tired(seg["from"], seg["to"])
        else:
            s.wired_segment(seg)
    s.accents()
    s.whips()
    s.finish()
    return s, H


# ---------------------------------------------------------------------------
# Standard MIDI Files
# ---------------------------------------------------------------------------
def vlq(n):
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(out)


def meta(kind, data):
    return bytes([0xFF, kind]) + vlq(len(data)) + data


def track_chunk(events):
    events.sort(key=lambda e: (e[0], e[1]))
    body, now = b"", 0
    for tick, _, data in events:
        body += vlq(tick - now) + data
        now = tick
    body += vlq(0) + meta(0x2F, b"")
    return b"MTrk" + struct.pack(">I", len(body)) + body


def conductor(cues, title):
    us = round(60_000_000 / TEMPO)
    ev = [(0, 0, meta(0x03, title.encode())), (0, 0, meta(0x51, us.to_bytes(3, "big"))),
          (0, 0, meta(0x58, bytes([4, 2, 24, 8]))), (0, 0, meta(0x59, bytes([0xFD, 1])))]   # C minor (3 flats)
    for c in cues:
        ev.append((round(c["beat"] * PPQ), 1, meta(0x06, c["name"].encode())))
    return ev


def part_events(part, notes):
    ch = part["ch"]
    ev = [(0, 0, meta(0x03, part["name"].encode()))]
    for start, pitch, vel, dur in notes:
        on = round(start * PPQ)
        off = max(on + 1, round((start + dur) * PPQ))
        ev.append((on, 2, bytes([0x90 | ch, pitch, vel])))
        ev.append((off, 1, bytes([0x80 | ch, pitch, 0])))
    return ev


def smf(tracks, fmt):
    return b"MThd" + struct.pack(">IHHH", 6, fmt, len(tracks), PPQ) + b"".join(track_chunk(t) for t in tracks)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def write_midi(cut, score, cues, outdir):
    os.makedirs(outdir, exist_ok=True)
    for f in os.listdir(outdir):
        if f.endswith(".mid"):
            os.remove(os.path.join(outdir, f))
    for i, part in enumerate(PARTS, 1):
        ev = conductor(cues, part["name"]) + part_events(part, score.notes[part["id"]])
        with open(os.path.join(outdir, f"{i:02d}-{slug(part['name'])}.mid"), "wb") as fh:
            fh.write(smf([ev], 0))
    tracks = [conductor(cues, cut.MIDI_TITLE)] + [part_events(p, score.notes[p["id"]]) for p in PARTS]
    with open(os.path.join(outdir, cut.MIDI_NAME), "wb") as fh:
        fh.write(smf(tracks, 1))


def cue_list(cut):
    cues = []
    n = {"TIRED": 0, "WIRED": 0}
    for t, state, label in cut.FLIPS:
        n[state] += 1
        cues.append({"name": f"{state} {n[state]}: {label}", "seconds": t})
    cues += [{"name": name, "seconds": t} for t, name in cut.EXTRA_CUES]
    cues.sort(key=lambda c: c["seconds"])
    for c in cues:
        c["beat"] = sec(c["seconds"])
        c["bar"] = int(c["beat"] // 4) + 1
    return cues


def arrangement_md(cut, data, H):
    total = cut.BARS * 4
    lines = [f"Generated by `score.py`: {TEMPO:g} BPM, 4/4, {cut.BARS} bars ({total / 2:.1f} s). "
             "Positions are Bitwig's bar.beat.16th (1.1.1 = 0 s). One beat is 0.5 s, one bar 2.0 s.", "",
             "Sections:", "", "| Section | From | Film time | What plays |", "| --- | --- | --- | --- |"]
    for s in data["sections"]:
        lines.append(f"| {s['name']} | {pos(s['beat'])} | {s['seconds']:.1f} s | {s['what']} |")
    lines += ["", "Every flip (each one lands exactly on its beat):", "",
              "| Film time | Position | Flip | On screen | Length | Harmony |", "| --- | --- | --- | --- | --- | --- |"]
    for s in data["segments"]:
        chords = []
        for a, b, c in H.spans:
            if s["from"] <= a < s["to"] and (not chords or chords[-1] != c):
                chords.append(c)
        shown = " ".join(chords[:4]) + (" ..." if len(chords) > 4 else "")
        n = s['to'] - s['from']
        label = s['label'].replace("|", "\\|")
        lines.append(f"| {s['from'] / 2:.1f} s | {pos(s['from'])} | {s['state']} | {label} | {n:g} beat{'s' if n != 1 else ''} | {shown} |")
    lines += ["", "Accents:", "", "| Film time | Position | On screen | In the score |", "| --- | --- | --- | --- |"]
    for a in data["accents"]:
        lines.append(f"| {a['seconds']:.2f} s | {pos(a['beat'])} | {a['what']} | {a['music']} |")
    lines += ["", "Cue markers: one per flip, plus " + ", ".join(n for _, n in cut.EXTRA_CUES) + "."]
    return "\n".join(lines)


def update_readme(here, cut, data, H):
    path = os.path.join(here, "README.md")
    if not os.path.exists(path):
        return
    text = open(path).read()
    block = "<!-- arrangement:start -->\n" + arrangement_md(cut, data, H) + "\n<!-- arrangement:end -->"
    text = re.sub(r"<!-- arrangement:start -->.*?<!-- arrangement:end -->", lambda m: block, text, flags=re.S)
    open(path, "w").write(text)


def bitwig_script(here, data):
    template = open(os.path.join(here, "bitwig", "template.control.js")).read()
    return template.replace("/*@SCORE@*/null", json.dumps(data, separators=(",", ":")))


def run(cut, here, doc):
    """Compose one cut and write its score.json, MIDI, controller script and README map."""
    ap = argparse.ArgumentParser(description=doc, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--install", action="store_true", help=f"copy the script to ~/Bitwig Studio/Controller Scripts/{VENDOR}/")
    args = ap.parse_args()

    F = Film(cut)
    score, H = compose(F)
    cues = cue_list(cut)
    data = {
        "title": cut.TITLE, "vendor": VENDOR, "uuid": cut.UUID, "source": cut.SOURCE,
        "tempo": TEMPO, "key": "C Dorian", "stepSize": STEP, "lengthBeats": F.total, "bars": cut.BARS, "groove": GROOVE,
        "segments": F.segs,
        "sections": [{"name": n, "seconds": t, "beat": sec(t), "what": w} for n, t, w in cut.SECTIONS],
        "accents": [{"seconds": t, "beat": sec(t), "what": w, "music": m} for t, w, m, _ in cut.ACCENTS],
        "harmony": [{"from": a, "to": b, "chord": c} for a, b, c in H.spans],
        "wiredParts": WIRED_PARTS, "tiredParts": TIRED_PARTS,
        "cues": cues, "fx": FX, "master": MASTER,
        "tracks": [dict(p, notes=score.notes[p["id"]]) for p in PARTS],
    }
    if getattr(cut, "CHECKS", None):
        data["checks"] = cut.CHECKS
    missing = [x["preset"] for x in PARTS + FX + [MASTER] if not os.path.exists(x["preset"])]
    missing += [i for p in PARTS for i in p.get("inserts", []) if not os.path.exists(i)]
    if missing:
        print("error: presets not found:\n  " + "\n  ".join(missing), file=sys.stderr)
        sys.exit(1)
    with open(os.path.join(here, "score.json"), "w") as fh:
        json.dump(data, fh, indent=1)
    write_midi(cut, score, cues, os.path.join(here, "midi"))
    path = os.path.join(here, "bitwig", f"{cut.TITLE}.control.js")
    with open(path, "w") as fh:
        fh.write(bitwig_script(here, data))
    update_readme(here, cut, data, H)
    if args.install:
        dest = os.path.expanduser(f"~/Bitwig Studio/Controller Scripts/{VENDOR}")
        os.makedirs(dest, exist_ok=True)
        shutil.copy(path, dest)
        print(f"installed {dest}/{os.path.basename(path)}")
    n = sum(len(score.notes[p["id"]]) for p in PARTS)
    print(f"{TEMPO:g} BPM, {F.total} beats ({F.total / 2:.1f} s), {len(PARTS)} parts, {n} notes, {len(cues)} markers")
    for p in PARTS:
        ns = score.notes[p["id"]]
        print(f"  {p['name']:<10} {len(ns):4d} notes, pitches {min(x[1] for x in ns)}-{max(x[1] for x in ns)}")
