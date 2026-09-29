import subprocess, sys, numpy as np
src = sys.argv[1]
W, H = 192, 108
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vf", f"fps=10,scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True, check=True).stdout
fr = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
print("frames", len(fr))
std = fr.std(axis=(1, 2))
diff = np.r_[99, np.abs(np.diff(fr, axis=0)).mean(axis=(1, 2))]
blank = [i / 10 for i in range(len(fr)) if std[i] < 4]
print("low-detail frames (std<4):", blank[:80], "count", len(blank))
run, holds = 0, []
for i, d in enumerate(diff):
    if d < 0.05:
        run += 1
    else:
        if run >= 15:
            holds.append(((i - run) / 10, i / 10))
        run = 0
if run >= 15:
    holds.append(((len(fr) - run) / 10, len(fr) / 10))
print("static holds >=1.5s:", holds)
