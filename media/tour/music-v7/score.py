#!/usr/bin/env python3
"""RubyLLM tour v7, "tired vs wired": the timing of the v7 cut.

The music is v6's, unchanged: key, loops, voicings, motif, parts, presets and
mix live in ../music-shared/tired_wired.py. This file holds only the v7
picture's timing. Running it writes

  score.json                           the score (parts, notes, harmony, segments, cues)
  midi/NN-<part>.mid                   one Standard MIDI File per part
  midi/rubyllm-tour-v7.mid             every part in one type-1 file, with the cues as markers
  bitwig/RubyLLM Tour v7.control.js    the Bitwig controller script that builds the project

  python3 music-v7/score.py            # write everything
  python3 music-v7/score.py --install  # also copy the script into Bitwig

The picture is 120 BPM, 4/4, 76 bars (152.0 s), and loops. It alternates
TIRED and WIRED on the 28 flips in ../video/v7/v7-cues.md. Every flip sits on
a beat, so the score lands on each one exactly. Standard library only.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "music-shared"))
import tired_wired  # noqa: E402

TITLE = "RubyLLM Tour v7"
UUID = "100309f3-db84-4920-9f37-ccfffad750a9"
SOURCE = "music-v7/score.py"
MIDI_NAME = "rubyllm-tour-v7.mid"
MIDI_TITLE = "RubyLLM tour v7"
BARS = 76                                 # 304 beats = 152.0 s

FLIPS = [
    (0.0, "TIRED", "raw request"), (4.0, "WIRED", "RubyLLM.chat.ask"),
    (8.5, "TIRED", "manual history"), (11.5, "WIRED", "chat.ask, chat.ask"),
    (14.5, "TIRED", "typed stream events"), (17.5, "WIRED", "chat.ask do |chunk|"),
    (26.0, "TIRED", "base64 content parts"), (29.0, "WIRED", "chat.ask with:"),
    (35.0, "TIRED", "tool schema by hand"), (38.5, "WIRED", "RubyLLM::Tool"),
    (47.0, "TIRED", "manual MCP client"), (50.5, "WIRED", "RubyLLM::MCP"),
    (60.0, "TIRED", "parse by hand"), (63.5, "WIRED", "with_schema"),
    (88.0, "TIRED", "Anthropic curl"), (91.5, "WIRED", "claude-opus-5-5"),
    (92.0, "TIRED", "Gemini curl"), (95.0, "WIRED", "gemini-3.8-flash"),
    (95.5, "TIRED", "Bedrock boto3"), (98.5, "WIRED", "provider: :bedrock"),
    (103.5, "TIRED", "speech curl"), (106.0, "WIRED", "speak / transcribe"),
    (110.0, "TIRED", "image curl, polling"), (112.5, "WIRED", "paint / animate"),
    (118.0, "TIRED", "embeddings curl"), (120.5, "WIRED", "embed / rerank"),
    (125.5, "TIRED", "OCR, moderation"), (128.0, "WIRED", "ocr / moderate"),
]

SECTIONS = [
    # name, start s, what the music does
    ("01 First ask", 0.0, "TIRED drag (muffled Rhodes, tape-slow horn, office drone, clock); snap at 4.0 s into the broken beat"),
    ("02 Conversation", 8.5, "TIRED, then the broken beat snaps back at 11.5 s"),
    ("03 Streaming into Rails", 14.5, "TIRED, then WIRED at 17.5 s with shaker and rim; vibes as the haiku streams, an open hat on the whip to Rails"),
    ("04 Files", 26.0, "TIRED, then four-on-the-floor jazz-house at 29.0 s; vibes on each with: variant"),
    ("05 Tools", 35.0, "TIRED, then WIRED at 38.5 s; vibes climb through the quicker walkthrough and the demo"),
    ("06 MCP", 47.0, "TIRED, then broken beat with open hats at 50.5 s; open hats and vibes on each server whip"),
    ("07 Structured output", 60.0, "TIRED, then jazz-house at 63.5 s; vibes on product.txt and the picked values"),
    ("08 Judge", 71.0, "Stays WIRED: broken beat on the Judge loop (Fm9, Bb13, Ebmaj9, Abmaj7#11); a brass stab on the 0.97"),
    ("09 Agent with approval", 78.0, "Stays WIRED: home loop, jazz-house; a brass stab on Approve; from 83.0 s the build into providers (ride, brass pushes)"),
    ("10 Providers (build)", 88.0, "Three flips 3.5 s apart: two one-beat snaps, then the logo wall at level 4 from 98.5 s"),
    ("11 speak + transcribe", 103.5, "TIRED, then WIRED at 106.0 s, level 4: ride, open hats, brass on the pushes"),
    ("12 paint + animate", 110.0, "TIRED, then WIRED at 112.5 s, level 4"),
    ("13 embed + rerank", 118.0, "TIRED, then WIRED at 120.5 s, level 4"),
    ("14 ocr + moderate", 125.5, "TIRED, then WIRED at 128.0 s, a riser into the climax"),
    ("15 Everything else (climax)", 132.0, "The peak across the feature grid: every part, brass on every push, the horn and vibes in call and answer; the whole band hits the collapse at 140.5 s"),
    ("16 Ending", 144.0, "Stop-time for the closing line, the whole band on Cm9 for \"Use Ruby.\" at 146.0 s, then Cm6/9 on the end card at 147.5 s, ringing into the loop"),
]

EXTRA_CUES = [(71.0, "Judge"), (78.0, "Agent"), (100.0, "Logo wall"), (132.0, "Climax"), (140.5, "Cards collapse"),
              (144.0, "Closing line (stop-time)"), (146.0, "Use Ruby."), (147.5, "End card"), (152.0, "Loop point")]

# Accents (every E3 in the cue MIDI, plus the camera whips inside WIRED), what
# answers them, and how: vibes, brass (stab and vibes), whip (open hat and
# vibes), walk (vibes climbing in order), skip (written with its section).
ACCENTS = [
    (6.35, "Answer tagged first.output", "vibes", "vibes"),
    (7.5, "Whip: answer lands on history.concat", "open hat, vibes", "whip"),
    (13.4, "Next prompt pops", "vibes", "vibes"),
    (14.0, "Prompt dives into the stream line", "open hat, vibes", "whip"),
    (17.85, "haiku.rb terminal opens", "vibes", "vibes"),
    (18.25, "Haiku streams", "vibes", "vibes"),
    (21.0, "Whip to Rails", "open hat, vibes", "whip"),
    (22.0, "Block morphs into ChatStreamJob", "vibes", "vibes"),
    (30.6, "with: variant 1", "vibes", "vibes"),
    (32.0, "with: variant 2", "vibes", "vibes"),
    (33.3, "with: variant 3", "vibes", "vibes"),
    (34.45, "Prompt pops for tools", "vibes", "vibes"),
    (39.25, "Walkthrough: class", "vibes", "walk"),
    (39.85, "Walkthrough: RubyLLM::Tool", "vibes", "walk"),
    (40.45, "Walkthrough: description", "vibes", "walk"),
    (41.05, "Walkthrough: execute", "vibes", "walk"),
    (41.75, "Walkthrough: with_tools", "vibes", "walk"),
    (42.6, "Tool demo thread", "vibes", "walk"),
    (54.5, "Cut down to the server row (GitHub)", "open hat, vibes", "whip"),
    (54.85, "Another server is three lines away.", "vibes", "vibes"),
    (56.0, "Whip: Notion", "open hat, vibes", "whip"),
    (57.0, "Whip: Atlassian", "open hat, vibes", "whip"),
    (58.0, "Whip: Sentry", "open hat, vibes", "whip"),
    (64.1, "product.txt", "vibes", "vibes"),
    (65.8, "Values picked out of the text", "vibes", "vibes"),
    (70.5, "Ticket pops", "vibes", "vibes"),
    (72.6, "model line", "vibes", "vibes"),
    (74.0, "urgent.probability 0.97", "brass stab, vibes", "brass"),
    (75.0, "frustration bars", "vibes", "vibes"),
    (82.5, "Approve click", "brass stab, vibes", "brass"),
    (86.5, "Push into model id", "vibes", "vibes"),
    (100.0, "Pull out to logo wall", "open hat, vibes", "whip"),
    (101.3, "19 providers. One Ruby API.", "brass stab, vibes", "brass"),
    (106.3, "Voice note appears", "vibes", "vibes"),
    (107.0, "Voice note plays", "vibes", "vibes"),
    (109.5, "Transcribed in place", "vibes", "vibes"),
    (112.85, "Panda painted", "vibes", "vibes"),
    (113.1, "Panda animates", "vibes", "vibes"),
    (121.0, "Vector numbers", "vibes", "vibes"),
    (122.6, "Rerank sorts by score", "vibes", "vibes"),
    (129.2, "PDF scans into Markdown", "vibes", "vibes"),
    (140.5, "Cards squash into labels", "impact, crash, brass, vibes: the whole band", "skip"),
    (146.0, "Use Ruby.", "impact, crash, brass, the whole band on Cm9", "skip"),
    (147.5, "End card", "Cm6/9, the horn's last call", "skip"),
]

# How each WIRED flip plays: groove style and level, and section changes inside
# the stretch (time, style, level, loop). The same levels as v6, except the build
# now starts in Agent (83.0 s) and the logo wall is at level 4.
WIRED_PLAN = {
    4.0: {"style": "bb", "level": 1}, 11.5: {"style": "bb", "level": 1}, 17.5: {"style": "bb", "level": 2},
    29.0: {"style": "house", "level": 2}, 38.5: {"style": "house", "level": 2}, 50.5: {"style": "bb", "level": 3},
    63.5: {"style": "house", "level": 3, "subs": [(71.0, "bb", 2, "judge"), (78.0, "house", 3, "home"), (83.0, "house", 4, "home")]},
    98.5: {"style": "house", "level": 4}, 106.0: {"style": "house", "level": 4}, 112.5: {"style": "house", "level": 4},
    120.5: {"style": "house", "level": 4}, 128.0: {"style": "house", "level": 4, "ending": True},
}

# The last WIRED stretch: no testimonials in v7, so the climax runs 132 to 144 s.
ENDING = {
    "climax": 132.0, "testimonials": None, "closing": 144.0, "use_ruby": 146.0, "end_card": 147.5,
    "climax_horn": [(0, "call", 104), (4, "answer", 104), (8, "call", 106), (12, "answer", 106), (20, "answer", 106)],
    "climax_hits": [(140.5, "hit")],
    "quotes": [],
}

# What verify.py checks beyond the flips.
CHECKS = {
    "cueMidi": "../video/v7/rubyllm-tour-v7-cues.mid",
    "video": "../video/v7/rubyllm-tour-v7-silent.mp4",
    "flips": 28,
    "climaxHit": tired_wired.sec(140.5),
    "closing": tired_wired.sec(144.0),
    "useRuby": tired_wired.sec(146.0),
    "endCard": tired_wired.sec(147.5),
}

if __name__ == "__main__":
    tired_wired.run(sys.modules[__name__], HERE, __doc__)
