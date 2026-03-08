import * as Tone from "https://cdn.jsdelivr.net/npm/tone@14.8.49/+esm";
import { Midi } from "https://cdn.jsdelivr.net/npm/@tonejs/midi@2.0.28/+esm";

const midiSelect = document.getElementById("midi-select");
const loadMidiButton = document.getElementById("load-midi-btn");
const playButton = document.getElementById("play-btn");
const stopButton = document.getElementById("stop-btn");
const statusText = document.getElementById("status-text");
const manifestHint = document.getElementById("manifest-hint");
const trackSection = document.getElementById("track-section");
const trackSummary = document.getElementById("track-summary");
const trackList = document.getElementById("track-list");

const INSTRUMENT_DEFINITIONS = [
  {
    id: "violin",
    label: "Violin",
    create: () => createPolyVoice({ oscillator: { type: "sawtooth" }, envelope: { attack: 0.02, decay: 0.2, sustain: 0.55, release: 1.1 } }, -6),
  },
  {
    id: "viola",
    label: "Viola",
    create: () => createPolyVoice({ oscillator: { type: "triangle" }, envelope: { attack: 0.03, decay: 0.2, sustain: 0.5, release: 1.0 } }, -7),
  },
  {
    id: "cello",
    label: "Cello",
    create: () => createPolyVoice({ oscillator: { type: "fatsawtooth" }, envelope: { attack: 0.025, decay: 0.22, sustain: 0.58, release: 1.15 } }, -8),
  },
  {
    id: "contrabass",
    label: "Contrabass",
    create: () => createPolyVoice({ oscillator: { type: "square" }, envelope: { attack: 0.03, decay: 0.24, sustain: 0.62, release: 1.2 } }, -9),
  },
  {
    id: "piano",
    label: "Piano",
    create: () => createPolyVoice({ oscillator: { type: "triangle" }, envelope: { attack: 0.005, decay: 0.25, sustain: 0.12, release: 0.65 } }, -5),
  },
  {
    id: "harp",
    label: "Harp",
    create: () => createPolyVoice({ oscillator: { type: "sine" }, envelope: { attack: 0.004, decay: 0.16, sustain: 0.05, release: 0.85 } }, -7),
  },
  {
    id: "flute",
    label: "Flute",
    create: () => createPolyVoice({ oscillator: { type: "sine" }, envelope: { attack: 0.02, decay: 0.15, sustain: 0.72, release: 0.45 } }, -9),
  },
  {
    id: "clarinet",
    label: "Clarinet",
    create: () => createPolyVoice({ oscillator: { type: "square" }, envelope: { attack: 0.014, decay: 0.18, sustain: 0.62, release: 0.55 } }, -8),
  },
  {
    id: "guitar",
    label: "Guitar",
    create: () => createPolyVoice({ oscillator: { type: "triangle" }, envelope: { attack: 0.003, decay: 0.22, sustain: 0.15, release: 0.34 } }, -7),
  },
  {
    id: "synth-pad",
    label: "Synth Pad",
    create: () => createPolyVoice({ oscillator: { type: "sine" }, envelope: { attack: 0.45, decay: 0.7, sustain: 0.75, release: 1.8 } }, -10),
  },
];

const INSTRUMENT_MAP = new Map(INSTRUMENT_DEFINITIONS.map((definition) => [definition.id, definition]));

const state = {
  midi: null,
  midiFileName: "",
  tracks: [],
  assignments: new Map(),
  instrumentPlayers: new Map(),
  parts: [],
  manifestFiles: [],
  instrumentsReady: false,
  playbackEndEventId: null,
};

class TrackInstrumentPlayer {
  constructor(definition) {
    this.definition = definition;
    this.voice = null;
  }

  load() {
    this.voice = this.definition.create();
  }

  triggerNote(pitch, velocity, startTime, duration) {
    if (!this.voice) {
      return;
    }
    const safeVelocity = clamp(velocity ?? 0.7, 0.05, 1);
    const safeDuration = Math.max(duration ?? 0.1, 0.05);
    this.voice.triggerAttackRelease(pitch, safeDuration, startTime, safeVelocity);
  }

  dispose() {
    if (this.voice) {
      this.voice.dispose();
      this.voice = null;
    }
  }
}

function createPolyVoice(synthOptions, volumeDb) {
  const synth = new Tone.PolySynth(Tone.Synth, synthOptions);
  const volume = new Tone.Volume(volumeDb);
  synth.connect(volume);
  volume.toDestination();

  return {
    triggerAttackRelease: (...args) => synth.triggerAttackRelease(...args),
    dispose: () => {
      synth.dispose();
      volume.dispose();
    },
  };
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function setStatus(message, level = "info") {
  statusText.textContent = message;
  statusText.dataset.level = level;
}

function sanitizeManifestFile(file) {
  if (typeof file !== "string") {
    return null;
  }
  const trimmed = file.trim();
  if (!trimmed || trimmed.includes("..") || trimmed.startsWith("/") || trimmed.startsWith("\\")) {
    return null;
  }
  return trimmed;
}

function isMidiFile(name) {
  return /\.(mid|midi)$/i.test(name);
}

function buildOutputUrl(fileName) {
  return `output/${fileName.split("/").map((segment) => encodeURIComponent(segment)).join("/")}`;
}

function chooseDefaultInstrument(track, index) {
  const hint = `${track.name || ""} ${track.instrumentHint || ""}`.toLowerCase();

  if (hint.includes("violin")) {
    return "violin";
  }
  if (hint.includes("viola")) {
    return "viola";
  }
  if (hint.includes("cello")) {
    return "cello";
  }
  if (hint.includes("contrabass") || hint.includes("double bass") || hint.includes("bass")) {
    return "contrabass";
  }
  if (hint.includes("piano") || hint.includes("keys")) {
    return "piano";
  }
  if (hint.includes("harp")) {
    return "harp";
  }
  if (hint.includes("flute")) {
    return "flute";
  }
  if (hint.includes("clarinet")) {
    return "clarinet";
  }
  if (hint.includes("guitar")) {
    return "guitar";
  }
  if (hint.includes("pad") || hint.includes("synth") || hint.includes("lead")) {
    return "synth-pad";
  }

  return INSTRUMENT_DEFINITIONS[index % INSTRUMENT_DEFINITIONS.length].id;
}

async function loadMidiManifest() {
  setStatus("Loading MIDI manifest...");

  try {
    const response = await fetch("output/midi-index.json", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const json = await response.json();
    if (!json || !Array.isArray(json.files)) {
      throw new Error("Manifest JSON must contain a 'files' array.");
    }

    const sanitizedFiles = json.files
      .map((entry) => sanitizeManifestFile(entry))
      .filter((entry) => entry && isMidiFile(entry));

    if (!sanitizedFiles.length) {
      throw new Error("No .mid or .midi entries found in output/midi-index.json.");
    }

    state.manifestFiles = sanitizedFiles;
    midiSelect.innerHTML = "";

    for (const file of sanitizedFiles) {
      const option = document.createElement("option");
      option.value = file;
      option.textContent = file;
      midiSelect.appendChild(option);
    }

    midiSelect.disabled = false;
    loadMidiButton.disabled = false;
    manifestHint.textContent = `${sanitizedFiles.length} MIDI file(s) available in output/.`;
    setStatus("Manifest loaded. Choose a MIDI file and click Load MIDI.");
  } catch (error) {
    midiSelect.disabled = true;
    loadMidiButton.disabled = true;
    manifestHint.textContent = "Could not read output/midi-index.json.";
    setStatus(`Manifest load failed: ${error.message}`, "error");
  }
}

function summarizeTrack(track, index) {
  const noteCount = track.notes.length;
  const noteNumbers = track.notes.map((note) => note.midi);
  const minNote = noteNumbers.length ? Math.min(...noteNumbers) : null;
  const maxNote = noteNumbers.length ? Math.max(...noteNumbers) : null;

  return {
    index,
    name: track.name?.trim() || "",
    noteCount,
    channel: track.channel,
    duration: track.duration || 0,
    instrumentHint: track.instrument?.name || "",
    rangeLabel: minNote !== null && maxNote !== null
      ? `${Tone.Frequency(minNote, "midi").toNote()} - ${Tone.Frequency(maxNote, "midi").toNote()}`
      : "",
  };
}

function renderTracks() {
  trackList.innerHTML = "";
  const nonEmpty = state.tracks.filter((track) => track.noteCount > 0).length;
  trackSummary.textContent = `${state.tracks.length} track(s) detected, ${nonEmpty} with notes.`;

  for (const track of state.tracks) {
    const row = document.createElement("article");
    row.className = "track-row";

    const title = document.createElement("h3");
    title.textContent = track.name ? `Track ${track.index + 1}: ${track.name}` : `Track ${track.index + 1}`;

    const meta = document.createElement("p");
    meta.className = "track-meta";
    const channel = typeof track.channel === "number" ? track.channel + 1 : "N/A";
    const rangePart = track.rangeLabel ? ` | Range: ${track.rangeLabel}` : "";
    meta.textContent = `Notes: ${track.noteCount} | Channel: ${channel} | Duration: ${track.duration.toFixed(2)}s${rangePart}`;

    const selector = document.createElement("select");
    selector.dataset.trackIndex = String(track.index);
    selector.setAttribute("aria-label", `Instrument for track ${track.index + 1}`);

    for (const instrument of INSTRUMENT_DEFINITIONS) {
      const option = document.createElement("option");
      option.value = instrument.id;
      option.textContent = instrument.label;
      selector.appendChild(option);
    }

    selector.value = state.assignments.get(track.index);
    selector.addEventListener("change", (event) => {
      const trackIndex = Number(event.target.dataset.trackIndex);
      state.assignments.set(trackIndex, event.target.value);
      state.instrumentsReady = false;
      setStatus("Instrument mapping updated. Instruments will reload on Play.");
    });

    row.appendChild(title);
    row.appendChild(meta);
    row.appendChild(selector);

    if (track.noteCount === 0) {
      const emptyHint = document.createElement("p");
      emptyHint.className = "empty-note";
      emptyHint.textContent = "Empty track (no notes to schedule).";
      row.appendChild(emptyHint);
    }

    trackList.appendChild(row);
  }

  trackSection.classList.remove("hidden");
}

function disposePlaybackParts() {
  for (const part of state.parts) {
    part.dispose();
  }
  state.parts = [];

  if (state.playbackEndEventId !== null) {
    Tone.Transport.clear(state.playbackEndEventId);
    state.playbackEndEventId = null;
  }
}

function disposeInstrumentPlayers() {
  for (const player of state.instrumentPlayers.values()) {
    player.dispose();
  }
  state.instrumentPlayers.clear();
  state.instrumentsReady = false;
}

function stopPlayback(updateStatus = true) {
  Tone.Transport.stop();
  Tone.Transport.cancel(0);
  disposePlaybackParts();
  stopButton.disabled = true;
  playButton.disabled = !state.midi;

  if (updateStatus) {
    setStatus("Playback stopped.");
  }
}

async function loadSelectedMidi() {
  const selectedFile = midiSelect.value;
  if (!selectedFile) {
    setStatus("Select a MIDI file first.", "error");
    return;
  }

  loadMidiButton.disabled = true;
  playButton.disabled = true;
  stopButton.disabled = true;
  setStatus(`Loading MIDI file: ${selectedFile}`);

  try {
    await Tone.start();
    stopPlayback(false);
    disposeInstrumentPlayers();

    const midiResponse = await fetch(buildOutputUrl(selectedFile), { cache: "no-store" });
    if (!midiResponse.ok) {
      throw new Error(`MIDI fetch failed (HTTP ${midiResponse.status}).`);
    }

    const arrayBuffer = await midiResponse.arrayBuffer();
    const midi = new Midi(arrayBuffer);
    state.midi = midi;
    state.midiFileName = selectedFile;
    state.tracks = midi.tracks.map((track, index) => summarizeTrack(track, index));

    if (!state.tracks.length) {
      throw new Error("MIDI parsed, but no tracks were found.");
    }

    state.assignments.clear();
    for (const track of state.tracks) {
      state.assignments.set(track.index, chooseDefaultInstrument(track, track.index));
    }

    renderTracks();
    await prepareInstruments();

    playButton.disabled = false;
    setStatus(`MIDI loaded: ${selectedFile}. Instruments ready.`);
  } catch (error) {
    state.midi = null;
    state.midiFileName = "";
    state.tracks = [];
    state.assignments.clear();
    disposeInstrumentPlayers();
    playButton.disabled = true;
    stopButton.disabled = true;
    setStatus(`Load failed: ${error.message}`, "error");
  } finally {
    loadMidiButton.disabled = false;
  }
}

async function prepareInstruments() {
  if (!state.midi) {
    throw new Error("No MIDI loaded.");
  }

  disposeInstrumentPlayers();

  for (const track of state.tracks) {
    if (track.noteCount === 0) {
      continue;
    }

    const selectedInstrumentId = state.assignments.get(track.index);
    const definition = INSTRUMENT_MAP.get(selectedInstrumentId);

    if (!definition) {
      throw new Error(`Unknown instrument '${selectedInstrumentId}' for track ${track.index + 1}.`);
    }

    try {
      const player = new TrackInstrumentPlayer(definition);
      player.load();
      state.instrumentPlayers.set(track.index, player);
    } catch (error) {
      throw new Error(`Instrument '${definition.label}' failed to load for track ${track.index + 1}: ${error.message}`);
    }
  }

  state.instrumentsReady = true;
}

function buildPlaybackParts() {
  if (!state.midi) {
    throw new Error("No MIDI loaded.");
  }

  stopPlayback(false);

  const firstTempo = state.midi.header?.tempos?.[0]?.bpm;
  Tone.Transport.bpm.value = Number.isFinite(firstTempo) ? firstTempo : 120;

  let playbackDuration = 0;

  state.midi.tracks.forEach((track, index) => {
    const player = state.instrumentPlayers.get(index);
    if (!player || !track.notes.length) {
      return;
    }

    const events = track.notes.map((note) => ({
      time: note.time,
      pitch: note.name,
      velocity: note.velocity,
      duration: note.duration,
    }));

    const part = new Tone.Part((time, event) => {
      player.triggerNote(event.pitch, event.velocity, time, event.duration);
    }, events).start(0);

    state.parts.push(part);

    for (const note of track.notes) {
      playbackDuration = Math.max(playbackDuration, note.time + note.duration);
    }
  });

  if (!state.parts.length) {
    throw new Error("No playable notes found in the loaded MIDI tracks.");
  }

  state.playbackEndEventId = Tone.Transport.scheduleOnce(() => {
    stopPlayback(false);
    setStatus("Playback finished.");
  }, playbackDuration + 0.1);
}

async function playMidi() {
  if (!state.midi) {
    setStatus("Load a MIDI file before playing.", "error");
    return;
  }

  try {
    await Tone.start();

    if (!state.instrumentsReady) {
      await prepareInstruments();
      setStatus("Instruments reloaded. Starting playback...");
    }

    buildPlaybackParts();

    Tone.Transport.position = 0;
    Tone.Transport.start("+0.05");

    playButton.disabled = true;
    stopButton.disabled = false;
    setStatus(`Playback started (${state.midiFileName}).`);
  } catch (error) {
    stopPlayback(false);
    setStatus(`Playback error: ${error.message}`, "error");
  }
}

loadMidiButton.addEventListener("click", () => {
  loadSelectedMidi();
});

playButton.addEventListener("click", () => {
  playMidi();
});

stopButton.addEventListener("click", () => {
  stopPlayback(true);
});

window.addEventListener("beforeunload", () => {
  stopPlayback(false);
  disposeInstrumentPlayers();
});

loadMidiManifest();