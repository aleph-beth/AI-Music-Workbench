# AI-Music-Workbench

AI-Music-Workbench is a collaborative repository for generating, transforming, and experimenting with algorithmic music using AI systems such as Codex and Claude. The project focuses on text-based music representations including ABC notation, MIDI, and symbolic music formats.

## Live Site

- https://aleph-beth.github.io/AI-Music-Workbench/

## PowerShell MIDI Scripts

### 1) Dynamic Classical String Quartet
- Script: `generate_quartet_midi.ps1`
- Output: `output/quatuor_classique_plus_4min_dynamique.mid`
- Features: string quartet (about 4 minutes), progressive dynamics, phrase accents.

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_quartet_midi.ps1
```

### 2) Electro / Techno Remix (Long Notes)
- Script: `generate_electro_remix_midi.ps1`
- Output: `output/remix_electro_techno_sons_longs.mid`
- Features: 128 BPM techno groove, electronic kick/hat, synth bass, sustained pads, long lead.

Command:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_electro_remix_midi.ps1
```

## Project Structure

- `generate_quartet_midi.ps1`: generates a format-1 MIDI classical string quartet.
- `generate_electro_remix_midi.ps1`: generates a format-1 MIDI electro/techno remix track.
- `output/`: generated MIDI files and static manifest.

## Web MIDI Interface (GitHub Pages)

This repository includes a static web interface compatible with GitHub Pages:

- `index.html`: UI layout (MIDI selection, loading, instrument mapping, playback controls)
- `style.css`: responsive styling
- `app.js`: frontend logic (manifest loading, MIDI parsing, instruments, playback scheduling)
- `output/midi-index.json`: MIDI manifest used for file listing

### Architecture Summary

1. MIDI manifest loading:
- The frontend fetches `output/midi-index.json`.
- No runtime directory listing is used.
- `.mid` and `.midi` entries populate the "Choose a MIDI file" dropdown.

2. MIDI parsing:
- `app.js` uses `@tonejs/midi` (browser ESM via CDN).
- Tracks are displayed with:
  - track number
  - optional track name
  - note count, channel, duration, and range

3. Per-track instrument mapping:
- A predefined instrument catalog is centralized in `INSTRUMENT_DEFINITIONS`.
- Each track has an independent instrument selector.
- A `TrackInstrumentPlayer` abstraction maps each track to a playable instrument object.

4. Synchronized playback:
- Tone.js `Transport` drives browser playback.
- Notes are scheduled per track with `Tone.Part` in sync.
- Controls: `Load MIDI`, `Play`, `Stop`.

## Updating the MIDI Manifest

When adding or removing MIDI files in `output/`, update `output/midi-index.json`:

```json
{
  "files": [
    "example_1.mid",
    "example_2.midi"
  ]
}
```

## GitHub Pages Deployment

1. Commit and push to `github.com/aleph-beth/AI-Music-Workbench`.
2. Open GitHub `Settings > Pages`.
3. Select `Deploy from a branch`.
4. Choose branch `main` (or another branch) and folder `/ (root)`.
5. Save.

Expected URL:

- https://aleph-beth.github.io/AI-Music-Workbench/

All frontend paths are relative (for example `output/...`), so the site works correctly under the repository subpath on GitHub Pages.