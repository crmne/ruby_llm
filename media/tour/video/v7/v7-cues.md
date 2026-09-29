# RubyLLM v7 "tired vs wired": cue sheet

- **Tempo:** 120 BPM, 4/4. One beat = 0.5 s, one bar = 2.0 s.
- **Length:** 152.0 s = 76 bars. Loops to 0.0.
- **Notation:** bar.beat is 1-based; 4.5 means halfway through beat 4.
- **TIRED** = muffled, low-passed, dragging bed under the dark verbose code. **WIRED** = bright after each snap. Every WIRED flip is the compression hit.
- Every flip, cut and section start sits on a beat. Accents are on-screen events to catch where the arrangement wants them.
- **Files:** `rubyllm-tour-v7-cues.mid` (markers; notes C3 = TIRED, D3 = WIRED snap, E3 = accent), `rubyllm-tour-v7-silent.mp4`.

## Sections

| Section | Start (s) | Bar.beat | Bars | Picture |
|---|---|---|---|---|
| 01 First ask | 0.0 | 1.1 | 4.25 | Raw request, implode into chat.ask; the answer takes the name first.output and lands on it |
| 02 Conversation | 8.5 | 5.2 | 3 | Manual history, vacuum into two chat.ask lines |
| 03 Streaming into Rails | 14.5 | 8.2 | 5.75 | Typed events fold into chat.ask do |chunk|; code + haiku.rb terminal; haiku into the browser, block morphs into ChatStreamJob |
| 04 Files | 26.0 | 14.1 | 4.5 | Base64 world shatters; chat.ask with: on two lines, three variants |
| 05 Tools | 35.0 | 18.3 | 6 | Hand-rolled tool loop folds; quicker walkthrough; demo thread |
| 06 MCP | 47.0 | 24.3 | 6.5 | Manual client vacuums into RubyLLM::MCP; GitHub, Notion, Atlassian, Sentry |
| 07 Structured output | 60.0 | 31.1 | 5.5 | Schema world shatters; values picked out of a messy product.txt into the Hash |
| 08 Judge | 71.0 | 36.3 | 3.5 | Ticket hand-off; model, question, verdict bars |
| 09 Agent with approval | 78.0 | 40.1 | 5 | Tool and job files, approval click, push into the model id |
| 10 Providers (build) | 88.0 | 45.1 | 7.75 | Each provider's API next to its RubyLLM line, three snaps, lines gather, logo wall |
| 11 speak + transcribe | 103.5 | 52.4 | 3.25 | Two curls, snap, one voice note plays then transcribes in place |
| 12 paint + animate | 110.0 | 56.1 | 4 | Two curls, snap, painted panda + longer animate clip |
| 13 embed + rerank | 118.0 | 60.1 | 3.75 | Two curls, snap, the vector's numbers; five documents sorted by score |
| 14 ocr + moderate | 125.5 | 63.4 | 3.25 | Two curls, snap, PDF page scans into Markdown; flagged? false |
| 15 Everything else (climax) | 132.0 | 67.1 | 6 | Dive out; twelve real snippet cards, two at a time; at 140.5 they squash into labels |
| 16 Ending | 144.0 | 73.1 | 4 | Closing line, Use Ruby., end card |

Arc: 0 to 26 s sets up the pattern (three flips); 26 to 71 s is one flip per feature; 71 to 88 s stays WIRED (Judge, Agent); 88 to 103.5 s is the build, three flips about 3.5 s apart with each provider's RubyLLM line on screen; 103.5 to 132 s is four pairs; 132 s is the climax (feature cards); 144 s stop-time for the closing line; 147.5 s final chord.

## Every flip, cut and accent

| Time (s) | Bar.beat | Type | On screen |
|---|---|---|---|
| 0.00 | 1.1 | Flip to TIRED | first ask (raw request) |
| 4.00 | 3.1 | Flip to WIRED | snap RubyLLM.chat.ask |
| 6.35 | 4.1.7 | Accent | Answer tagged first.output |
| 7.50 | 4.4 | Cut/camera | Whip: answer (tagged first.output) lands on history.concat(first.output) |
| 8.50 | 5.2 | Flip to TIRED | conversation (manual history) |
| 11.50 | 6.4 | Flip to WIRED | snap chat.ask, chat.ask |
| 13.40 | 7.3.8 | Accent | Next prompt pops |
| 14.00 | 8.1 | Cut/camera | Prompt dives into the stream line |
| 14.50 | 8.2 | Flip to TIRED | streaming (typed events) |
| 17.50 | 9.4 | Flip to WIRED | snap chat.ask do |chunk| |
| 17.85 | 9.4.7 | Accent | haiku.rb terminal opens |
| 18.25 | 10.1.5 | Accent | Haiku streams |
| 21.00 | 11.3 | Cut/camera | Whip to Rails: haiku into the browser, block into chat_stream_job.rb |
| 22.00 | 12.1 | Accent | Block morphs into ChatStreamJob |
| 26.00 | 14.1 | Cut/camera | Whip into files world (chips fly out of the chat) |
| 26.00 | 14.1 | Flip to TIRED | files (base64 content parts) |
| 29.00 | 15.3 | Flip to WIRED | snap chat.ask with: |
| 30.60 | 16.2.2 | Accent | with: variant 1 |
| 32.00 | 17.1 | Accent | with: variant 2 |
| 33.30 | 17.3.6 | Accent | with: variant 3 |
| 34.45 | 18.1.9 | Accent | Prompt pops for tools |
| 35.00 | 18.3 | Cut/camera | Whip into tools world |
| 35.00 | 18.3 | Flip to TIRED | tools (JSON schema by hand) |
| 38.50 | 20.2 | Flip to WIRED | snap RubyLLM::Tool |
| 39.25 | 20.3.5 | Accent | Walkthrough: class |
| 39.85 | 20.4.7 | Accent | Walkthrough: RubyLLM::Tool |
| 40.45 | 21.1.9 | Accent | Walkthrough: description |
| 41.05 | 21.3.1 | Accent | Walkthrough: execute |
| 41.75 | 21.4.5 | Accent | Walkthrough: with_tools |
| 42.60 | 22.2.2 | Accent | Tool demo thread |
| 47.00 | 24.3 | Cut/camera | Whip into MCP world |
| 47.00 | 24.3 | Flip to TIRED | MCP (manual client) |
| 50.50 | 26.2 | Flip to WIRED | snap RubyLLM::MCP |
| 54.50 | 28.2 | Cut/camera | Cut down to the server row (GitHub) |
| 54.85 | 28.2.7 | Accent | Title: Another server is three lines away. |
| 56.00 | 29.1 | Cut/camera | Whip: Notion |
| 57.00 | 29.3 | Cut/camera | Whip: Atlassian |
| 58.00 | 30.1 | Cut/camera | Whip: Sentry |
| 59.50 | 30.4 | Cut/camera | Whip into the tilted structured-output world |
| 60.00 | 31.1 | Flip to TIRED | structured output (parse by hand) |
| 63.50 | 32.4 | Flip to WIRED | snap with_schema |
| 64.10 | 33.1.2 | Accent | product.txt |
| 65.80 | 33.4.6 | Accent | Values picked out of the text |
| 70.50 | 36.2 | Accent | Ticket pops |
| 71.00 | 36.3 | Cut/camera | Whip to Judge, ticket travels |
| 71.00 | 36.3 | Section | Judge (cut) |
| 72.60 | 37.2.2 | Accent | model line |
| 74.00 | 38.1 | Accent | urgent.probability 0.97 |
| 75.00 | 38.3 | Accent | frustration bars |
| 78.00 | 40.1 | Cut/camera | Whip to Agent, ticket travels |
| 78.00 | 40.1 | Section | Agent (cut) |
| 81.00 | 41.3 | Cut/camera | Push-in on approval |
| 82.50 | 42.2 | Accent | Approve click |
| 83.00 | 42.3 | Cut/camera | Pull back to tool file |
| 86.50 | 44.2 | Cut/camera | Push into model id |
| 87.50 | 44.4 | Cut/camera | Whip into Anthropic world |
| 88.00 | 45.1 | Flip to TIRED | Anthropic curl |
| 91.50 | 46.4 | Flip to WIRED | snap claude-opus-5-5 |
| 92.00 | 47.1 | Cut/camera | Whip to Gemini |
| 92.00 | 47.1 | Flip to TIRED | Gemini curl |
| 95.00 | 48.3 | Flip to WIRED | snap gemini-3.8-flash |
| 95.50 | 48.4 | Cut/camera | Whip to Bedrock |
| 95.50 | 48.4 | Flip to TIRED | Bedrock boto3 |
| 98.50 | 50.2 | Flip to WIRED | snap provider: :bedrock |
| 99.00 | 50.3 | Cut/camera | The three lines gather into a stack |
| 100.00 | 51.1 | Cut/camera | Pull out to logo wall |
| 100.00 | 51.1 | Section | logo wall build |
| 101.30 | 51.3.6 | Accent | 19 providers. One Ruby API. |
| 103.00 | 52.3 | Cut/camera | Whip to speak/transcribe |
| 103.50 | 52.4 | Flip to TIRED | speech + transcription (curl) |
| 106.00 | 54.1 | Flip to WIRED | snap RubyLLM.speak / RubyLLM.transcribe |
| 106.30 | 54.1.6 | Accent | Voice note appears |
| 107.00 | 54.3 | Accent | Voice note plays |
| 109.50 | 55.4 | Accent | Transcribed in place |
| 109.50 | 55.4 | Cut/camera | Whip to paint/animate |
| 110.00 | 56.1 | Flip to TIRED | image + video generation (curl, polling) |
| 112.50 | 57.2 | Flip to WIRED | snap RubyLLM.paint / RubyLLM.animate |
| 112.85 | 57.2.7 | Accent | Panda painted |
| 113.10 | 57.3.2 | Accent | Panda animates |
| 117.50 | 59.4 | Cut/camera | Whip to embed/rerank |
| 118.00 | 60.1 | Flip to TIRED | embeddings + rerank (curl) |
| 120.50 | 61.2 | Flip to WIRED | snap RubyLLM.embed / RubyLLM.rerank |
| 121.00 | 61.3 | Accent | Vector numbers |
| 122.60 | 62.2.2 | Accent | Rerank sorts by score |
| 125.00 | 63.3 | Cut/camera | Whip to ocr/moderate |
| 125.50 | 63.4 | Flip to TIRED | OCR + moderation |
| 128.00 | 65.1 | Flip to WIRED | snap RubyLLM.ocr / RubyLLM.moderate |
| 129.20 | 65.3.4 | Accent | PDF scans into Markdown |
| 132.00 | 67.1 | Cut/camera | Camera dives out; feature cards begin 132.8 |
| 132.00 | 67.1 | Section | CLIMAX everything else |
| 140.50 | 71.2 | Accent | Cards squash into labels |
| 144.00 | 73.1 | Cut/camera | Punch-in to the closing line |
| 144.00 | 73.1 | Section | closing line (stop-time hit) |
| 146.00 | 74.1 | Cut/camera | Use Ruby. |
| 147.50 | 74.4 | Cut/camera | Pan down to end card |
| 147.50 | 74.4 | Section | end card (final chord) |
| 151.50 | 76.4 | Cut/camera | Fade to background |
| 152.00 | 77.1 | Cut/camera | End (loops to 0) |
