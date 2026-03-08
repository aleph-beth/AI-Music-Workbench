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

## Interface web MIDI (GitHub Pages)

Cette branche inclut une interface statique compatible GitHub Pages:

- `index.html`: structure UI (selection MIDI, chargement, mapping instruments, lecture/arret)
- `style.css`: style responsive
- `app.js`: logique frontend (manifest, parsing MIDI, instruments, scheduling playback)
- `output/midi-index.json`: manifeste des fichiers MIDI exposes

### Architecture resumee

1. Chargement du manifeste:
- Le frontend lit `output/midi-index.json` (pas de listing repertoire runtime).
- Les entrees `.mid` / `.midi` alimentent le select "Choose a MIDI file".

2. Parsing MIDI:
- `app.js` utilise `@tonejs/midi` (CDN ESM browser) pour parser le fichier selectionne.
- Chaque piste detectee est affichee avec:
  - numero de piste
  - nom (si disponible)
  - nombre de notes, canal, duree, tessiture

3. Mapping instruments par piste:
- Une liste predefinie d'instruments est centralisee dans `INSTRUMENT_DEFINITIONS`.
- Chaque piste a son select instrument independant.
- Le mapping est charge en objets de playback via une abstraction `TrackInstrumentPlayer`.

4. Lecture synchronisee:
- `Tone.js` pilote le transport audio en navigateur.
- Les notes de chaque piste sont planifiees dans des `Tone.Part` synchronises.
- Boutons disponibles: `Load MIDI`, `Play`, `Stop`.

### Mise a jour du manifeste MIDI

Quand vous ajoutez/supprimez des fichiers MIDI dans `output/`, mettez a jour `output/midi-index.json`:

```json
{
  "files": [
    "mon_fichier_1.mid",
    "mon_fichier_2.midi"
  ]
}
```

### Deploiement GitHub Pages

1. Commit/push de la branche vers `github.com/aleph-beth/AI-Music-Workbench`.
2. Dans GitHub: `Settings > Pages`.
3. Source: `Deploy from a branch`.
4. Branch: `main` (ou branche choisie), dossier: `/ (root)`.
5. Sauvegarder.

URL attendue:

- `https://aleph-beth.github.io/AI-Music-Workbench/`

Tous les chemins web sont relatifs (`output/...`), donc compatibles avec le sous-chemin du repository sur GitHub Pages.
