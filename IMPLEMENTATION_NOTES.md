# Implementation Notes

Running log of discovered assumptions, changes, test results, and rollback steps. Newest entries first.

---

## 2026-08-24 — Part A kickoff (laptop)

### Discovered state (laptop)

- Host: MacBook, **arm64**. Git 2.50.1, Docker 29.5.2, Node 24. No Homebrew, no `gh` CLI, no global git identity.
- Existing repos on disk: `~/Code/internal-homelab-portal` (LAN-only family portal — **out of scope**, untouched), `~/Code/nas-homelab-codebase` (PHP, unrelated), `~/Code/investor-hub` (source of git identity).
- `~/Code/one-page-arcade/`: the arcade. Single-file self-contained HTML games + `ARCHITECTURE.md` (game conventions) + `ghost-theme-assets/` (current Ghost deployment: `page-arcade.hbs`, `js/games.json`). `deploy-arcade.sh` scp's 8 games to `chuck@thor:~/data/ghost/themes/journal/`.
- **No game screenshots exist** anywhere in the arcade folder (games.json references `*.png` that were never created) → screenshot capture is a pending task.
- Ghost currently lives on `thor` at `~/data/ghost/`, theme `journal`. Public site: `https://choukalos.com` behind a **Cloudflare tunnel** with **Caddy on thor doing reverse-proxy duties** (per owner).

### Decisions (owner, 2026-08-24)

1. Public GitHub repo named `homelab-blog`.
2. **Laptop is the build machine**: Hugo (pinned binary v0.165.0, darwin-arm64, `~/bin`) builds; `deploy.sh` pushes built site to `deploy` branch; git-sync on thor consumes it. Supersedes the brief's CI-build recommendation (its hard requirement — no build tooling in the public container — still met).
3. Same public URL as Ghost: `https://choukalos.com`; edge (Cloudflare tunnel + thor Caddy) kept as-is; cutover re-points the route.
4. Arcade: merge the `one-page-arcade` folder in; **7 games** (asteroids, galaga, missile-command, tetris, depth-charge, elite, lunar-lander); exclude `joust.html` (broken) and `rolling-thunder.html` (deprioritized); themed index page with screenshots + maker/year/details; more games later (data-driven via `data/arcade/games.json`).
5. Blog starts fresh — no Ghost post migration.
6. Status panel: placeholder now; publisher + public-Grafana integration deferred.
7. Skills Runner is a real component on thor; `publish_file` proceeds as planned.
8. Part B stays a **draft** until a pi run on thor discovers the actual architecture and revises it.
9. Git identity: `Chuck Choukalos <chuck@Chucks-MacBook-Air.local>` (reused from `investor-hub`; owner to confirm).

### Changes made

- `architecture.md` v0.2, `README.md`, `PLAN.md` (two-part plan), this file.
- Hugo v0.165.0 installed to `~/bin/hugo` (prebuilt binary; no Homebrew).
- Hugo site scaffolded: `hugo.toml`, `content/{thoughts,lab}`, `layouts/` (baseof/single/list/index + partials), `assets/{css,js}`, `static/arcade/` (7 games + `data/arcade/games.json`), `deploy.sh`, `scripts/new-thought.sh`.
- Theme: cyberpunk/brick CSS tokens, brick cards, neon accents, scanline hero, `prefers-reduced-motion`, accessible focus/contrast; no external fonts/CDN.
- Homepage modules: SYSTEM STATUS (placeholder-safe `status/status.json` fetch), ARCADE, LATEST DROP, RECENT THOUGHTS.
- `/arcade/` index: data-driven cards from `games.json` (screenshot with CSS placeholder fallback, title, company, year, description).

### Tests / validation

- (pending) `hugo --minify --gc` build, `hugo server` smoke test of all routes, mobile/keyboard walkthrough.

### Rollback

- Nothing on the server has been touched. Laptop repo is pre-first-push; deleting the GitHub repo (or not creating it) fully reverts Part A. Ghost on thor is unchanged and remains the live site.

### Open items

- [ ] Create public GitHub repo `homelab-blog` + first push (needs `gh auth login` or manual creation).
- [ ] Confirm git identity.
- [ ] Capture arcade screenshots (headless browser) → `static/arcade/shots/`.
- [ ] 404 page + polish pass.
- [ ] Part B discovery + revision on thor (pi run).