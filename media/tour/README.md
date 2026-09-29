# RubyLLM tour

The source of the tour video on the [rubyllm.com](https://rubyllm.com) homepage. The finished video and its music live on the [v2.0.0 release](https://github.com/crmne/ruby_llm/releases/tag/v2.0.0) as `rubyllm-tour.mp4` and `rubyllm-tour-music.flac`.

| Folder | What it holds |
| --- | --- |
| `video/hyperframes/` | The [HyperFrames](https://hyperframes.heygen.com) composition. `index.html` is the built film; `src/` and `tools/` generate it. |
| `video/v7/` | The cue sheet and cue MIDI every cut, snap, and music flip follows: 120 BPM, 76 bars, 152 s. |
| `music-shared/` | The "tired versus wired" score material: key, loops, voicings, motif, presets, and mix. |
| `music-v7/` | The score arranged to the cue sheet, its MIDI, the Bitwig controller script that builds it, and `RubyLLM.bwproject` with the final mix. |

## Render the video

Render the silent picture, then add the music from the release:

```sh
cd video/hyperframes
npm run render -- --fps 60 --quality delivery --output rubyllm-tour-silent.mp4
ffmpeg -i rubyllm-tour-silent.mp4 -i rubyllm-tour-music.flac \
  -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -movflags +faststart rubyllm-tour.mp4
```

## Rebuild the music

Open `music-v7/RubyLLM.bwproject` in Bitwig Studio 6 to get the final mix. To regenerate the score from scratch, run `python3 music-v7/score.py`, install `music-v7/bitwig/RubyLLM Tour v7.control.js` as a controller script, and press Build. `music-v7/README.md` has the arrangement map and the Bitwig steps.

Timing is fixed: every cut, snap, and music flip sits on the grid in `video/v7/v7-cues.md`. Keep that file identical when you change the picture or the score.
