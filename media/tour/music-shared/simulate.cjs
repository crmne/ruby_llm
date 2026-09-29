// Runs the generated controller script against a fake Bitwig host: a small
// model of a project (tracks, devices, sends, faders, launcher clips, cue
// markers, groove, transport) where every action lands after a delay, like the
// real thing. It presses Build twice (the second must change nothing but the
// clips), then Lengths (with a clip shortened by hand, then restored), then
// Record, and checks the project against score.json.
//
//   node music-shared/simulate.cjs music-v7
//   SIM_REFUSE_LENGTH=1 node music-shared/simulate.cjs music-v7   # forces the duplicateContent fallback
//   SIM_LOG=1 node music-shared/simulate.cjs music-v7             # prints the whole console log
//
// It can't hear anything or prove Bitwig accepts every call; it proves the
// script's sequencing, lookups, idempotency and read-back loops, and that every
// value it reads was marked interested in init() (Bitwig throws otherwise).
//
// It models what Carmine hit in Bitwig 6.1.1: createEmptyClip makes a one-bar
// clip whatever length it's asked for, and sets on the clip's range are
// dropped unless the value was subscribed (markInterested) in init().

"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const dir = path.resolve(process.argv[2] || path.join(__dirname, "..", "music-v7"));
const here = path.join(dir, "bitwig");
const score = JSON.parse(fs.readFileSync(path.join(here, "..", "score.json"), "utf8"));
const scriptPath = path.join(here, score.title + ".control.js");

// ------------------------------------------------------------ virtual time
let now = 0;
let seq = 0;
let queue = [];
function schedule(fn, ms) { queue.push({ at: now + Math.max(0, ms), fn, seq: seq++ }); }
function tick() { if (project.playing) project.position += (10 / 1000) * project.tempo / 60; }
function runUntilIdle(limitMs) {
  const end = now + limitMs;
  while (now < end) {
    queue.sort((a, b) => a.at - b.at || a.seq - b.seq);
    const due = queue.filter(e => e.at <= now);
    queue = queue.filter(e => e.at > now);
    for (const e of due) e.fn();
    if (!queue.length && !project.playing) return;
    now += 10;
    tick();
  }
  throw new Error("simulation did not settle in " + limitMs + " ms");
}

// ------------------------------------------------------------ the project
function channelData(name) { return { name, devices: [], slot: null, sends: {}, volume: 0.794, pan: 0.5, color: null }; }
const project = {
  tempo: 110, timeSig: "4/4", position: 0, playing: false, arrangerRecord: false, preRoll: "one_bar",
  tracks: [channelData("Inst 1"), channelData("Audio 1")],
  fx: [], master: [], markers: [], selected: null, recorded: [], launched: false,
  groove: { enabled: 0, rate: 0, amount: 0 },
};
const LAG = 120;
const REFUSE_LENGTH = process.env.SIM_REFUSE_LENGTH === "1";

const log = [];
const dropped = [];
const errors = [];
const popups = [];

// Bitwig's fader taper, as the script assumes it: amplitude 2x^3.
function dbText(x) { return x <= 0 ? "-inf dB" : (20 * Math.log10(2 * x * x * x)).toFixed(1) + " dB"; }

function value(get, set, label, display) {
  let interested = false;
  let shownInterested = false;
  const v = {
    markInterested() { interested = true; },
    get() { if (!interested) throw new Error("value read without markInterested: " + label); return get(); },
    getRaw() { return v.get(); },
    set(x) {
      if (v.dropUnlessInterested && !interested) { dropped.push(label); return; }
      if (typeof x === "number" && v.normalized) assert(x >= 0 && x <= 1, label + " set out of range: " + x);
      schedule(() => set(x), 20);
    },
    setRaw(x) { v.set(x); },
    addValueObserver() {},
    displayedValue() {
      return {
        markInterested() { shownInterested = true; },
        get() { if (!shownInterested) throw new Error("displayed value read without markInterested: " + label); return display ? display(get()) : String(get()); },
      };
    },
  };
  return v;
}
const fnv = v => () => v;

function deviceBank(list, label) {
  const items = {};
  return {
    getItemAt(i) {
      if (!items[i]) {
        items[i] = {
          exists: fnv(value(() => !!list()[i], () => {}, label + " device exists " + i)),
          name: fnv(value(() => (list()[i] || {}).name || "", () => {}, label + " device name " + i)),
        };
      }
      return items[i];
    },
  };
}

function presetDevice(file) {
  assert(fs.existsSync(file), "preset missing: " + file);
  const m = file.match(/\/Presets\/([^/]+)\//);
  return { name: m ? m[1] : path.basename(file, ".bwpreset"), preset: file };
}

function channel(getList, i, label) {
  const t = () => getList()[i];
  let slotItem = null;
  const slotBank = {
    getItemAt() {
      return slotItem || (slotItem = {
        hasContent: fnv(value(() => !!(t() && t().slot), () => {}, label + " hasContent " + i)),
        select() { schedule(() => { project.selected = t(); }, LAG); },
        showInEditor() {},
      });
    },
    createEmptyClip(slot, len) { schedule(() => { t().slot = { asked: len, playStart: 0, playStop: 4, loopStart: 0, loopLength: 4, notes: new Map(), loop: true, name: "", shuffle: false }; }, LAG); },
    deleteClip() { schedule(() => { t().slot = null; if (project.selected === t()) project.selected = null; }, LAG); },
  };
  const sendItems = {};
  const sends = {
    getItemAt(j) {
      if (!sendItems[j]) {
        const s = value(() => { const fx = project.fx[j]; return fx && t() && t().sends[fx.name] !== undefined ? t().sends[fx.name] : 0; },
          x => { t().sends[project.fx[j].name] = x; }, label + " " + i + " send " + j, dbText);
        s.normalized = true;
        sendItems[j] = s;
      }
      return sendItems[j];
    },
  };
  const vol = value(() => (t() ? t().volume : 0), x => { t().volume = x; }, label + " volume " + i, dbText);
  vol.normalized = true;
  const pan = value(() => (t() ? t().pan : 0.5), x => { t().pan = x; }, label + " pan " + i);
  pan.normalized = true;
  const color = value(() => (t() ? t().color : null), () => {}, label + " color " + i);
  color.set = (r, g, b) => { assert([r, g, b].every(x => x >= 0 && x <= 1), "colour"); schedule(() => { t().color = [r, g, b]; }, 20); };
  return {
    exists: fnv(value(() => !!t(), () => {}, label + " exists " + i)),
    name: fnv(value(() => (t() ? t().name : ""), x => { t().name = x; }, label + " name " + i)),
    volume: () => vol,
    pan: () => pan,
    color: () => color,
    clipLauncherSlotBank: () => slotBank,
    createDeviceBank: () => deviceBank(() => (t() ? t().devices : []), label + " " + i),
    startOfDeviceChainInsertionPoint: () => ({ insertFile(f) { const d = presetDevice(f); schedule(() => t().devices.unshift(d), LAG * 3); } }),
    endOfDeviceChainInsertionPoint: () => ({ insertFile(f) { const d = presetDevice(f); schedule(() => t().devices.push(d), LAG * 3); } }),
    sendBank: () => sends,
  };
}

function bank(getList, label) {
  const items = {};
  return { getItemAt(i) { return items[i] || (items[i] = channel(getList, i, label)); }, sceneBank: () => sceneBank };
}

const sceneBank = {
  getScene() {
    return {
      launch() {
        schedule(() => {
          project.launched = true;
          if (!project.playing) project.playing = true;
          if (project.arrangerRecord) project.recording = true;
        }, LAG);
      },
    };
  },
};

let stepObserver = null;
const cursorClip = {
  getTrack() { return this.track || (this.track = { name: fnv(value(() => (project.selected ? project.selected.name : ""), () => {}, "cursor clip track")) }); },
  addStepDataObserver(fn) { stepObserver = fn; },
  setStepSize(s) { assert.strictEqual(s, score.stepSize); this.step = s; },
  scrollToKey(k) { assert.strictEqual(k, 0); },
  scrollToStep(s) { assert.strictEqual(s, 0); },
  clearSteps() {
    const c = project.selected.slot;
    schedule(() => { for (const k of c.notes.keys()) { const [x, y] = k.split(":"); stepObserver(+x, +y, 0); } c.notes.clear(); }, 10);
  },
  setStep(ch, x, y, vel, dur) {
    assert.strictEqual(ch, 0);
    assert(Number.isInteger(x) && x >= 0 && x < score.lengthBeats / score.stepSize, "x out of the grid: " + x);
    assert(Number.isInteger(y) && y >= 0 && y < 128, "y out of range: " + y);
    assert(vel >= 1 && vel <= 127, "velocity " + vel);
    assert(dur > 0 && x * score.stepSize + dur <= score.lengthBeats + 1e-9, "note past the end: " + x + " + " + dur);
    const c = project.selected.slot;
    schedule(() => { c.notes.set(x + ":" + y, { x, y, vel, dur }); stepObserver(x, y, 2); }, 30);
  },
  isLoopEnabled() { return this.range("loop"); },
  getPlayStart() { return this.range("playStart"); },
  getPlayStop() { return this.range("playStop"); },
  getLoopStart() { return this.range("loopStart"); },
  getLoopLength() { return this.range("loopLength"); },
  getShuffle() { return this.range("shuffle"); },
  range(field) {
    this.ranges = this.ranges || {};
    if (!this.ranges[field]) {
      const v = value(() => (project.selected && project.selected.slot ? project.selected.slot[field] : 0),
        x => { if (!REFUSE_LENGTH || field === "loop" || field === "shuffle") project.selected.slot[field] = x; }, "cursor clip " + field);
      v.dropUnlessInterested = true;
      this.ranges[field] = v;
    }
    return this.ranges[field];
  },
  duplicateContent() {
    schedule(() => {
      const c = project.selected.slot;
      const len = c.loopLength;
      for (const n of [...c.notes.values()]) c.notes.set((n.x + len / score.stepSize) + ":" + n.y, Object.assign({}, n, { x: n.x + len / score.stepSize }));
      c.loopLength = len * 2;
      c.playStop = Math.max(c.playStop, len * 2);
      project.doublings = (project.doublings || 0) + 1;
    }, LAG);
  },
  setName(n) { project.selected.slot.name = n; },
};

const markerItems = {};
const markerBank = {
  getItemAt(i) {
    if (!markerItems[i]) {
      const m = () => project.markers.slice().sort((a, b) => a.pos - b.pos)[i];
      markerItems[i] = {
        exists: fnv(value(() => !!m(), () => {}, "marker exists " + i)),
        name: fnv(value(() => (m() ? m().name : ""), v => { m().name = v; }, "marker name " + i)),
        position: fnv(value(() => (m() ? m().pos : 0), v => { m().pos = v; }, "marker position " + i)),
      };
    }
    return markerItems[i];
  },
};

const grooveApi = {
  en: value(() => project.groove.enabled, x => { project.groove.enabled = x; }, "groove enabled", x => (x ? "On" : "Off")),
  rate: value(() => project.groove.rate, x => { project.groove.rate = x; }, "shuffle rate", x => (x >= 0.5 ? "1/16" : "1/8")),
  amount: value(() => project.groove.amount, x => { project.groove.amount = x; }, "shuffle amount", x => (x * 100).toFixed(1) + " %"),
};

const signals = {};
const host = {
  loadAPI(v) { assert.strictEqual(v, 25); },
  setShouldFailOnDeprecatedUse() {},
  defineController(vendor, name, version, uuid, author) {
    assert(/^[0-9a-f-]{36}$/.test(uuid), "uuid");
    assert(/^[0-9.]+$/.test(version), "plain version string: " + version);
    host.defined = { vendor, name, version, uuid, author };
  },
  defineMidiPorts(i, o) { assert.strictEqual(i + o, 0); },
  println(s) { log.push(s); },
  errorln(s) { errors.push(s); },
  showPopupNotification(s) { popups.push(s); },
  scheduleTask(fn, ms) { schedule(fn, ms); },
  createApplication: () => ({
    createInstrumentTrack(pos) { assert.strictEqual(pos, -1); schedule(() => project.tracks.push(channelData("Inst " + (project.tracks.length + 1))), LAG * 2); },
    createEffectTrack(pos) { assert.strictEqual(pos, -1); schedule(() => project.fx.push(channelData("FX " + (project.fx.length + 1))), LAG * 2); },
  }),
  createGroove: () => ({ getEnabled: () => grooveApi.en, getShuffleRate: () => grooveApi.rate, getShuffleAmount: () => grooveApi.amount }),
  createTransport: () => {
    const tempo = value(() => project.tempo, v => { project.tempo = v; }, "tempo");
    const playing = value(() => project.playing, () => {}, "isPlaying");
    const pos = value(() => project.position, () => {}, "playPosition");
    const rec = value(() => project.arrangerRecord, v => { project.arrangerRecord = v; }, "arranger record");
    const pre = value(() => project.preRoll, v => { project.preRoll = v; }, "preRoll");
    return {
      tempo: () => ({ value: () => tempo }),
      timeSignature: () => ({ set(v) { project.timeSig = v; } }),
      isPlaying: () => playing,
      playPosition: () => pos,
      isArrangerRecordEnabled: () => rec,
      preRoll: () => pre,
      setPosition(b) { schedule(() => { project.position = b; }, 30); },
      addCueMarkerAtPlaybackPosition() { schedule(() => project.markers.push({ name: "Marker " + (project.markers.length + 1), pos: project.position }), LAG); },
      play() { schedule(() => { project.playing = true; }, 30); },
      stop() { schedule(() => { project.playing = false; if (project.recording) { project.recorded.push(project.position); project.recording = false; } }, 30); },
      returnToArrangement() { project.backToArrangement = true; },
    };
  },
  createArranger: () => ({ createCueMarkerBank: () => markerBank }),
  createMainTrackBank: () => bank(() => project.tracks, "track"),
  createEffectTrackBank: () => bank(() => project.fx, "fx"),
  createMasterTrack: () => ({
    createDeviceBank: () => deviceBank(() => project.master, "master"),
    endOfDeviceChainInsertionPoint: () => ({ insertFile(f) { const d = presetDevice(f); schedule(() => project.master.push(d), LAG * 3); } }),
  }),
  createLauncherCursorClip: (w, h) => { assert.strictEqual(w, score.lengthBeats / score.stepSize); assert.strictEqual(h, 128); return cursorClip; },
  getPreferences: () => ({
    getSignalSetting(label, category, action) {
      assert.strictEqual(category, score.title);
      return { addSignalObserver(fn) { signals[action] = fn; } };
    },
  }),
};

// ------------------------------------------------------------ run it
const source = fs.readFileSync(scriptPath, "utf8");
assert(!/=>|\blet\b|\bconst\b|`/.test(source.replace(/"(?:[^"\\\n]|\\.)*"/g, "").replace(/\/\/.*$/gm, "")), "keep the script ES5");
const ctx = { host, Math, JSON, Object, String, parseFloat, isNaN };
vm.createContext(ctx);
vm.runInContext("function loadAPI(v) { host.loadAPI(v); }\n" + source, ctx, { filename: path.basename(scriptPath) });
ctx.init();
assert.deepStrictEqual(Object.keys(signals).sort(), ["Build", "Lengths", "Record", "Stop"]);
assert.strictEqual(host.defined.vendor, "Carmine");
assert.strictEqual(host.defined.name, score.title);

function press(action, ms) {
  signals[action]();
  runUntilIdle(ms);
  if (errors.length && process.env.SIM_LOG) console.log(log.join("\n"));
  assert.deepStrictEqual(errors, [], "errors after " + action + ":\n" + errors.join("\n"));
}

function dbOf(x) { return 20 * Math.log10(2 * x * x * x); }

function check() {
  assert.strictEqual(project.tempo, score.tempo);
  assert.strictEqual(project.groove.enabled, 1, "groove on");
  assert(Math.abs(project.groove.amount * 100 - score.groove.shuffle) <= 0.25, "shuffle amount " + project.groove.amount);
  for (const fx of score.fx) {
    const t = project.fx.filter(f => f.name === fx.name);
    assert.strictEqual(t.length, 1, "return track " + fx.name);
    assert.strictEqual(t[0].devices.length, 1);
    assert.strictEqual(t[0].devices[0].preset, fx.preset);
    assert(Math.abs(dbOf(t[0].volume) - fx.db) <= 0.3, fx.name + " fader " + dbOf(t[0].volume));
  }
  for (const part of score.tracks) {
    const t = project.tracks.filter(x => x.name === part.name);
    assert.strictEqual(t.length, 1, "one track named " + part.name);
    const tr = t[0];
    const inserts = part.inserts || [];
    assert.strictEqual(tr.devices.length, 1 + inserts.length, part.name + " devices");
    assert.strictEqual(tr.devices[0].preset, part.preset, part.name + " instrument first");
    inserts.forEach((f, k) => assert.strictEqual(tr.devices[1 + k].preset, f, part.name + " insert " + k));
    assert.deepStrictEqual(tr.color, part.color, part.name + " colour");
    assert.strictEqual(tr.pan, part.pan, part.name + " pan");
    assert(Math.abs(dbOf(tr.volume) - part.db) <= 0.3, part.name + " fader " + dbOf(tr.volume).toFixed(2) + " dB, wanted " + part.db);
    for (const fx of score.fx) {
      const want = part.sends[fx.name];
      const got = tr.sends[fx.name] || 0;
      if (want === undefined) assert.strictEqual(got, 0, part.name + " send " + fx.name + " off");
      else assert(Math.abs(dbOf(got) - want) <= 0.3, part.name + " send " + fx.name + " " + dbOf(got).toFixed(2) + " dB, wanted " + want);
    }
    assert(tr.slot, part.name + " clip");
    const c = tr.slot;
    assert.strictEqual(c.loop, false, part.name + " doesn't loop");
    assert.strictEqual(c.playStart, 0);
    assert.strictEqual(c.shuffle, !!part.shuffle, part.name + " shuffle");
    if (REFUSE_LENGTH) assert(c.playStop >= score.lengthBeats, part.name + " plays the whole part (doubled): " + c.playStop);
    else { assert.strictEqual(c.playStop, score.lengthBeats, part.name + " plays the whole part: " + c.playStop); assert.strictEqual(c.loopLength, score.lengthBeats); }
    assert.strictEqual(c.name, part.name);
    assert.strictEqual(c.notes.size, part.notes.length, part.name + " note count");
    for (const n of part.notes) {
      const got = c.notes.get(Math.round(n[0] / score.stepSize) + ":" + n[1]);
      assert(got && got.vel === n[2] && Math.abs(got.dur - n[3]) < 1e-9, part.name + " note " + JSON.stringify(n));
    }
  }
  assert.strictEqual(project.master.filter(d => d.name === score.master.device).length, 1, "one master compressor");
  assert.strictEqual(project.markers.length, score.cues.length, "marker count");
  for (const c of score.cues) {
    const m = project.markers.filter(x => x.name === c.name);
    assert.strictEqual(m.length, 1, "marker " + c.name);
    assert(Math.abs(m[0].pos - c.beat) < 0.01, "marker position " + c.name);
  }
  assert.strictEqual(project.tracks.length, 2 + score.tracks.length, "left the existing tracks alone");
  assert.strictEqual(project.tracks[0].name, "Inst 1");
  assert.strictEqual(project.tracks[0].devices.length, 0, "didn't touch the first track");
}

press("Build", 1200000);
check();
const firstLog = log.length;
const buildTime = now;
press("Build", 1200000);
check();
assert(log.slice(firstLog).some(l => /exists at/.test(l)), "second build reused tracks");
assert(!log.slice(firstLog).some(l => /creating/.test(l)), "second build created nothing");
assert(!log.slice(firstLog).some(l => /adding .* after the instrument/.test(l)), "second build added no inserts");
popups.length = 0;
const pad = project.tracks.find(x => x.name === "Keys");
pad.slot.playStop = 4;                                  // someone shortened one by hand
press("Lengths", 120000);
assert(popups.some(p => /1 clip\(s\) short: Keys: 4 beats/.test(p)), "Lengths reports the short clip: " + popups.join(" | "));
pad.slot.playStop = score.lengthBeats;
popups.length = 0;
press("Lengths", 120000);
assert(popups.some(p => new RegExp("^" + score.title + ": all " + score.tracks.length + " clips play " + score.lengthBeats + " beats \\(" + score.lengthBeats / 4 + " bars\\)").test(p)), "Lengths: " + popups.join(" | "));
assert(log.some(l => new RegExp("Keys: " + score.lengthBeats + " beats \\(" + score.lengthBeats / 4 + " bars").test(l)), "logs the Keys length");
press("Record", 300000);
assert.strictEqual(project.recorded.length, 1, "one take");
assert(project.recorded[0] >= score.lengthBeats, "recorded the whole score: " + project.recorded[0]);
assert(project.recorded[0] < score.lengthBeats + 2, "stopped soon after the last bar: " + project.recorded[0]);
assert.strictEqual(project.arrangerRecord, false, "disarmed");
assert.strictEqual(project.preRoll, "one_bar", "pre-roll restored");
assert(project.backToArrangement, "back to the arrangement");
assert.strictEqual(project.position, 0);

assert.deepStrictEqual(dropped, [], "sets on values the script never subscribed: " + dropped.join(", "));
if (process.env.SIM_LOG) console.log(log.join("\n"));
if (REFUSE_LENGTH) assert(project.doublings > 0, "fell back to duplicateContent");
console.log(popups.join("\n"));
console.log(`\nok: ${score.tracks.length} tracks, ${score.fx.length} returns, ` +
  `${score.tracks.reduce((a, t) => a + t.notes.length, 0)} notes, ${score.cues.length} markers, faders/sends/pans/colours/inserts/shuffle checked, ` +
  `idempotent rebuild, record stopped at beat ${project.recorded[0].toFixed(2)}; first Build took ${(buildTime / 1000).toFixed(0)} s simulated`);
