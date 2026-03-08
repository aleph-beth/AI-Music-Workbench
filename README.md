# AI-Music-Workbench
A collaborative repository for generating, transforming, and experimenting with algorithmic music using AI systems such as Codex and Claude.  The project focuses on text-based musical representations including ABC notation, MIDI, and symbolic music formats, enabling reproducible music generation workflows and AI-assisted composition.

## Scripts MIDI PowerShell

### 1) Quatuor classique dynamique
- Script: `generate_quartet_midi.ps1`
- Sortie: `output/quatuor_classique_plus_4min_dynamique.mid`
- Caractéristiques: quatuor a cordes (~4 min), dynamique progressive, accentuation par phrases.

Commande:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_quartet_midi.ps1
```

### 2) Remix electro / techno (sons longs)
- Script: `generate_electro_remix_midi.ps1`
- Sortie: `output/remix_electro_techno_sons_longs.mid`
- Caractéristiques: groove techno 128 BPM, kick/hat electroniques, basse synthe, pads tenus et lead long.

Commande:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate_electro_remix_midi.ps1
```

## Structure
- `generate_quartet_midi.ps1`: generation MIDI format 1 d'un quatuor a cordes.
- `generate_electro_remix_midi.ps1`: generation MIDI format 1 d'un morceau electro/techno oriente remix.
- `output/`: fichiers MIDI generes.
