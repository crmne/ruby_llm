#!/usr/bin/env python3
"""ROUGH PREVIEW of a "tired vs wired" cut's score.json with a toy numpy synth, to check timing only.

This is not the music: the real sound is Bitwig's presets. It's a quick way to
hear the parts against the picture before building in Bitwig.

  python3 music-shared/preview.py music-v7    # music-v7/preview/rough-preview.wav, a timing plot,
                                      # and the silent video with the preview under it

Writes into <cut>/preview/ (ignored by git). Needs numpy (and matplotlib for the
plot); the video needs ffmpeg, which copies the picture untouched and only
encodes the audio.
"""

import json
import os
import subprocess
import sys
import wave

import numpy as np

HERE = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "music-v7"))
OUT = os.path.join(HERE, "preview")
SR = 48000
rng = np.random.default_rng(7)

GAIN = {"kick": 0.60, "snare": 0.20, "clap": 0.14, "hat": 0.07, "ohat": 0.06, "ride": 0.05, "shaker": 0.04, "rim": 0.10,
        "crash": 0.09, "bass": 0.34, "sub": 0.20, "keys": 0.07, "horn": 0.15, "brass": 0.06, "vibes": 0.07,
        "riser": 0.10, "impact": 0.45, "tkeys": 0.10, "thorn": 0.14, "drone": 0.10, "thud": 0.50, "tick": 0.10}
ALIAS = {"ride": "ohat", "shaker": "hat", "sub": "bass", "horn": "lead", "brass": "stab", "vibes": "bells",
         "tkeys": "keys", "thorn": "lead", "drone": "pad", "thud": "kick", "tick": "rim"}
TIRED = {"tkeys", "thorn", "drone", "thud", "tick"}


def hz(p):
    return 440.0 * 2 ** ((p - 69) / 12)


def noise(n):
    return rng.standard_normal(n)


def hp(x, k=1):
    for _ in range(k):
        x = np.diff(x, prepend=0.0)
    return x


def voice(kind, pitch, dur, vel):
    v = (vel / 127) ** 1.5
    f = hz(pitch)
    if kind == "kick":
        n = int(0.35 * SR); t = np.arange(n) / SR
        ph = 2 * np.pi * np.cumsum(48 + 110 * np.exp(-t * 28)) / SR
        return np.sin(ph) * np.exp(-t * 9) * v
    if kind in ("clap", "snare"):
        n = int(0.22 * SR); t = np.arange(n) / SR
        body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * (0.6 if kind == "snare" else 0)
        return (hp(noise(n)) * 0.5 * np.exp(-t * (22 if kind == "clap" else 16)) + body) * v
    if kind in ("hat", "ohat"):
        n = int((0.05 if kind == "hat" else 0.3) * SR); t = np.arange(n) / SR
        return hp(noise(n), 2) * 0.3 * np.exp(-t * (70 if kind == "hat" else 9)) * v
    if kind == "rim":
        n = int(0.06 * SR); t = np.arange(n) / SR
        return np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 80) * v
    if kind == "crash":
        n = int(2.2 * SR); t = np.arange(n) / SR
        return hp(noise(n), 2) * 0.35 * np.exp(-t * 1.8) * v
    if kind == "impact":
        n = int(2.0 * SR); t = np.arange(n) / SR
        ph = 2 * np.pi * np.cumsum(f * (1 + 2 * np.exp(-t * 12))) / SR
        return (np.sin(ph) * np.exp(-t * 2.2) + noise(n) * 0.25 * np.exp(-t * 14)) * v
    if kind == "riser":
        n = int(dur * SR); t = np.arange(n) / SR
        return hp(noise(n)) * 0.4 * (t / max(dur, 1e-3)) ** 2 * v
    n = int((dur + 0.4) * SR); t = np.arange(n) / SR
    gate = np.where(t < dur, 1.0, np.exp(-(t - dur) * 12))
    if kind == "bass":
        return (np.sin(2 * np.pi * f * t) + 0.15 * np.sin(4 * np.pi * f * t)) * gate * np.minimum(1, t * 400) * v
    if kind in ("keys",):
        return (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)) * np.exp(-t * 2.5) * gate * v
    if kind == "pad":
        s = sum(np.sin(2 * np.pi * f * k * t) / k ** 2 for k in range(1, 5))
        return s * np.minimum(1, t / 0.3) * gate * v
    if kind == "stab":
        s = sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, 6))
        return s * np.exp(-t * 7) * gate * v
    if kind in ("lead", "arp"):
        s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t)
        return s * np.exp(-t * (4 if kind == "lead" else 9)) * gate * v
    if kind == "bells":
        s = np.sin(2 * np.pi * f * t + 1.5 * np.sin(2 * np.pi * f * 3.5 * t) * np.exp(-t * 6))
        return s * np.exp(-t * 3) * v
    raise ValueError(kind)


def render(score):
    spb = 60.0 / score["tempo"]
    total = int(score["lengthBeats"] * spb * SR)
    mix = np.zeros(total + 3 * SR)
    stems = {}
    for tr in score["tracks"]:
        pid = tr["id"]
        buf = np.zeros_like(mix)
        for start, pitch, vel, dur in tr["notes"]:
            s = voice(ALIAS.get(pid, pid), pitch, dur * spb, vel)
            i = int(round(start * spb * SR))
            buf[i:i + len(s)] += s[: len(buf) - i]
        if pid in TIRED:                                   # the low-pass on the TIRED tracks
            X = np.fft.rfft(buf)
            f = np.fft.rfftfreq(len(buf), 1 / SR)
            buf = np.fft.irfft(X / np.sqrt(1 + (f / 450) ** 4), len(buf))
        stems[pid] = buf * GAIN[pid]
        mix += stems[pid]
    mix = mix[:total]
    mix = np.tanh(mix / max(1e-9, np.max(np.abs(mix))) * 1.6) * 0.89
    return mix, stems


def write_wav(path, x):
    x16 = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(x16.tobytes())


def plot(path, mix, score):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    hop = SR // 100
    rms = np.sqrt(np.convolve(mix ** 2, np.ones(hop) / hop, mode="same")[::hop])
    t = np.arange(len(rms)) / 100
    fig, ax = plt.subplots(figsize=(18, 4.2), dpi=110)
    ax.fill_between(t, 20 * np.log10(rms + 1e-4), -80, color="#9b1c24", alpha=0.85, lw=0)
    for s in score["segments"]:
        if s["state"] == "TIRED":
            ax.axvspan(s["from"] / 2, s["to"] / 2, color="#888", alpha=0.25, lw=0)
        else:
            ax.axvline(s["from"] / 2, color="#d11", lw=1.2)
    for s in score["sections"]:
        ax.text(s["seconds"] + 0.2, -2, s["name"][:2], fontsize=7, va="top")
    for a in score["accents"]:
        ax.axvline(a["seconds"], color="#2a6fdb", lw=0.5, alpha=0.5, ls="--")
    end = score["lengthBeats"] / 2
    ax.set_xlim(0, end); ax.set_ylim(-60, 0); ax.set_xticks(range(0, int(end) + 1, 4))
    ax.set_xlabel("seconds (blue: accents; numbers: sections)"); ax.set_ylabel("RMS dB")
    ax.set_title(score["title"] + ": rough preview level; grey = TIRED, red lines = WIRED flips (timing only, not the sound)")
    fig.tight_layout(); fig.savefig(path)


def main():
    score = json.load(open(os.path.join(HERE, "score.json")))
    os.makedirs(OUT, exist_ok=True)
    mix, _ = render(score)
    wav = os.path.join(OUT, "rough-preview.wav")
    write_wav(wav, mix)
    print(f"wrote {wav} ({len(mix) / SR:.2f} s)")
    try:
        plot(os.path.join(OUT, "rough-preview-timing.png"), mix, score)
        print("wrote", os.path.join(OUT, "rough-preview-timing.png"))
    except ImportError:
        pass
    video = os.path.join(HERE, score["checks"]["video"])
    if os.path.exists(video):
        out = os.path.join(OUT, "rough-preview-with-video.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-i", wav, "-map", "0:v", "-map", "1:a",
                        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out], check=True)
        print("wrote", out)


if __name__ == "__main__":
    main()
