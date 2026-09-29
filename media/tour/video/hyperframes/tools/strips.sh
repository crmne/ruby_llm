#!/usr/bin/env bash
# 12-frame strips and every-frame (1/30 s) sheets for the compressions
cd "$(dirname "$0")/../renders"
for spec in "first-ask 2.45" "conversation 9.95" "files 27.45" "mcp 48.95" "provider-anthropic 89.95" "speak-transcribe 104.75"; do set -- $spec
  ffmpeg -v error -y -ss $2 -t 1.92 -i rubyllm-tour-v8.3-master.mp4 -vf "fps=6.25,scale=640:-1,drawtext=text='%{pts\:flt}':x=6:y=6:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.7,tile=4x3:padding=4" -frames:v 1 -q:v 3 strips/compress-$1.jpg
  ffmpeg -v error -y -ss $2 -t 1.92 -i rubyllm-tour-v8.3-master.mp4 -vf "fps=30,scale=320:-1,drawtext=text='%{pts\:flt}':x=4:y=4:fontsize=14:fontcolor=white:box=1:boxcolor=black@0.7,tile=8x8:padding=2" -frames:v 1 -q:v 3 strips/dense-$1.jpg
done
