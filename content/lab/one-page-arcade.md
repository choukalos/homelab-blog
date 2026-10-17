---
title: "One-Page Arcade"
date: 2026-08-24
draft: false
tags: [arcade, games]
summary: "Classic arcade games rebuilt as single-file HTML — canvas rendering, procedural Web Audio sound, zero dependencies."
---

The arcade is a collection of classic games, each rebuilt as **one self-contained HTML file**: HTML5 Canvas rendering, inline CSS (CRT scanlines, HUD), vanilla JavaScript, and procedural sound via the Web Audio API. No frameworks, no build tools, no external assets — open the file and play.

## Conventions

Every game follows the same structure (see the arcade's `ARCHITECTURE.md` in the source repo):

- `resize()` — canvas sizing
- `ensureAudio()` / `playSound()` — procedural oscillators + noise buffers
- `initGame()` / `update()` / `draw()` / `loop()` — the standard game loop
- `localStorage` — hi-score persistence

## Current roster

| Game | Maker | Year |
|---|---|---|
| Asteroids | Atari | 1979 |
| Galaga | Namco | 1981 |
| Depth Charge | Atari | 1977 |
| Elite | Firelight/Lucid Dreams | 1984 |
| Missile Command | Atari | 1980 |
| Tetris | Electronorgtechnika | 1984 |
| Lunar Lander | Atari | 1979 |
| Pitfall! | Atari | 1982 |
| Kung Fu Master | Irem | 1984 |
| Double Dragon | Technos | 1987 |
| Star Wars | Midway | 1983 |
| Star Trek | GT Interactive (Vectrex) | 1983 |
| Zombie City: Last Stand | Original | 2025 |
| Alpine Rush | Original | 2026 |

The two **Original** titles are real-time 3D (Three.js inlined in the file); the rest are 2D canvas builds. More games will be added over time — the index is data-driven, so a new game is one HTML file plus one JSON entry.