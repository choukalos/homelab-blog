# Implementation Plan — Two Parts

> Split of the work in `docs/brief/homelab_portal_implementation_brief.pdf` by **where it happens**:
> **Part A** = dev laptop (this machine, this repo) — content, theme, build, Git.
> **Part B** = server `thor` — serving, publishing, cutover. **DRAFT: to be revised on thor after S0 discovery** (owner will run pi on thor to firm this up against the actual deployed architecture).
>
> Phases are ordered; each has acceptance criteria. Resolved decisions: see `architecture.md` §12.

---

## Part A — Dev laptop (this machine)

Everything here produces **source or built output**. All of it lives in this repo and is checked into Git. Nothing in Part A touches the server.

### A0. Tooling & repo setup
- [x] Repo: public GitHub `homelab-blog` (repo creation + first push pending — needs `gh auth` or manual repo creation)
- [x] Hugo installed as pinned prebuilt binary: `v0.165.0` darwin-arm64 → `~/bin/hugo` (no Homebrew; laptop is arm64, server is x86 — binary choice only matters here)
- [x] Git identity: `Chuck Choukalos <chuck@Chucks-MacBook-Air.local>` (confirm)
- [x] `.gitignore` (`.DS_Store`, `public/`, `resources/_temp/`, `.hugo_build.lock`)
- [x] Brief moved to `docs/brief/`
- [ ] Push to GitHub (owner: create public repo or `gh auth login`)

**Acceptance:** repo exists on GitHub, first commit pushed, `hugo version` works locally.

### A1. Hugo scaffold + arcade merge
- [x] `hugo.toml`: title, `baseURL = https://choukalos.com/`, permalinks (`/thoughts/:slug/`, `/lab/:slug/`), build config
- [x] `content/thoughts/` + `content/lab/` with sample posts (front-matter per `architecture.md` §8)
- [x] `layouts/`: `baseof`, `single`, `list`, `index` + partials (header, footer, nav, status)
- [x] Merge `~/Code/one-page-arcade/` → `static/arcade/`: **7 games** (asteroids, galaga, missile-command, tetris, depth-charge, elite, lunar-lander). Excluded: `joust.html` (broken), `rolling-thunder.html` (deprioritized), `_bad`/scratch files, raw frame dumps
- [x] `data/arcade/games.json` metadata (title, company, year, description, gameFile, screenshot) — data-driven index so future games = 1 file + 1 JSON entry
- [ ] **Arcade screenshots**: capture one in-game frame per game via headless browser (e.g. `npx playwright screenshot`) into `static/arcade/shots/`; until then the index shows CSS placeholder art

**Acceptance:** `hugo server` renders `/`, `/thoughts/`, `/thoughts/<sample>/`, `/lab/`, `/arcade/` with all 7 games playable; `hugo --minify --gc` build succeeds.

### A2. Theme / visual system (80s cyberpunk + brick-built)
- [x] CSS tokens: near-black/navy base; cyan/magenta/violet/amber accents; monospace display type + readable sans body (system font stacks — no external fonts)
- [x] Brick-built card modules (chunky borders, stud rows, neon glow), restrained scan-line + hover + arcade-button motion
- [x] Responsive/mobile-first; `prefers-reduced-motion` honored
- [x] Accessibility: accessible contrast (neon as accent, not body color), semantic HTML, keyboard navigation, visible focus states, alt text
- [x] No external CDN/runtime dependencies
- [ ] Polish pass: hover/scanline tuning, empty states, 404 page

**Acceptance:** theme passes a manual mobile-viewport + keyboard-only walkthrough; no neon-on-neon body text; reduced-motion mode verified.

### A3. Homepage modules
- [x] **SYSTEM STATUS**: fetches `status/status.json` client-side; renders friendly tiles + overall state + last-updated; **placeholder mode** when file missing/stale (publisher is deferred — must not break the page)
- [x] **ARCADE**: large visual tile → `/arcade/`
- [x] **LATEST DROP**: link into `/files/` (404 locally is expected; must not break)
- [x] **RECENT THOUGHTS**: 2–3 newest posts, not a blog-first layout

**Acceptance:** homepage works with and without `status.json`; all modules render on mobile + desktop.

### A4. Content authoring workflow
- [x] `scripts/new-thought.sh`: creates `content/thoughts/$(date +%F)-slug.md` with front-matter
- [x] `deploy.sh`: `hugo --minify --gc` → publish built site to `deploy` branch (clone-based, no worktree leaks; first run creates the branch)
- [x] Workflow documented in README (write → preview → commit → `./deploy.sh`)
- [x] **Ghost migration: skipped (owner decision — start fresh)**

**Acceptance:** a new post can be created + previewed in under a minute; `deploy.sh` dry-run logic verified (first real run after GitHub push is set up).

### A5. Local validation + docs
- [x] `architecture.md` v0.2, `README.md`, `PLAN.md`, `IMPLEMENTATION_NOTES.md`
- [ ] Full local checklist: all routes, 7 arcade games, mobile viewport, keyboard nav, reduced-motion, missing `status.json`, `/files/` link behavior
- [ ] Tag `v0.1` when Part A is complete (after GitHub push + screenshots)

**Acceptance:** Part A acceptance list in §4 below all pass locally.

---

## Part B — Server (`thor`) — **DRAFT, pending S0 discovery on thor**

To be executed on the server by a pi run on thor. **Inspect before editing** — do not assume paths, proxy software, UID/GID, ports, or the existing Caddy reverse proxy / Cloudflare tunnel layout. Record findings in `IMPLEMENTATION_NOTES.md`. Keep Ghost running until cutover validation passes.

> ⚠️ This part is a draft. The owner will run pi on thor, discover the actual architecture (existing Caddy reverse proxy behind the Cloudflare tunnel, Ghost compose, Skills Runner, networks, UID/GID), and revise these phases before execution.

### S0. Discovery & inventory *(brief Phase 0)*
- [ ] Inventory Ghost compose/config, the existing Caddy reverse proxy (site blocks, upstreams, TLS), Cloudflare tunnel config, Docker networks, ports, volume roots, UID/GID, health-check conventions
- [ ] Inventory Skills Runner: skill registration, mounts, validation patterns, response schema, tests
- [ ] Confirm GitHub `deploy` branch is reachable from thor (public repo → no credentials needed)
- [ ] Locate the arcade files currently deployed to the Ghost theme (`~/data/ghost/themes/journal/`)
- [ ] Identify the public Grafana (future status source) and any other monitoring usable read-only
- [ ] Produce a discovered-state summary + proposed file-change list **before editing**; revise this Part B from it

**Acceptance:** one-page discovered-state summary committed to `IMPLEMENTATION_NOTES.md`; revised Part B; no edits yet.

### S1. Filesystem + boundaries *(brief Phase 1)*
- [ ] Create `/homelab/data/public-site/{git,runtime}` and `/homelab/data/media/public/{ai,files,images,audio,video}` with least-privilege ownership for git-sync / status-publisher / Skills Runner; Caddy stays read-only
- [ ] No-symlinks policy for the public drop zone; explicit UID/GID on shared mounts

**Acceptance:** ownership/permissions verified per consumer; Caddy mounts (when added) are `ro`.

### S2. Caddy origin + themed `/files/` *(brief Phase 3)*
- [ ] `compose.yaml` + `Caddyfile` for the `portal` service: internal-only port, existing network conventions, pinned Caddy version, `read_only` root FS, no Docker socket
- [ ] Serve: generated site from git-sync `current` (ro) · `/files/*` from the public drop (ro, custom `browse-template.html`) · `/status/*` from runtime (ro, deferred)
- [ ] Browse template: portal styling, breadcrumb, dirs-first, filename/size/mtime, PUBLIC DROP banner, inline-SVG icons, no JS required, no filesystem/path leakage
- [ ] Security headers for a static site; **active-content policy**: block or force-download `.html/.htm/.js` in the drop zone
- [ ] Add the portal origin as a new upstream behind the existing Caddy reverse proxy (route added, Ghost still serving — no cutover yet)

**Acceptance:** origin reachable internally; `/files/` nested dirs + multiple types browse correctly; active types blocked/forced-download; Caddy mounts all read-only.

### S3. git-sync deployment *(brief Phase 4)*
- [ ] git-sync v4 container against `github.com/<owner>/homelab-blog` branch `deploy`: current `--link current` / `--period 30s` semantics, pinned version (public repo → no credential needed)
- [ ] Verify: a `deploy.sh` push from the laptop changes the portal **without restarting Caddy** and without partial updates

**Acceptance:** push a test revision → live change within ~30s; atomic swap observed (no mixed-revision files).

### S4. Status publisher *(brief Phase 5) — DEFERRED*
- [ ] Smallest reasonable publisher (script or tiny container, no public ingress): read the public Grafana or explicitly configured health checks only
- [ ] Writes `status.json` atomically every 30–60s: friendly names, coarse states, `updated_at`, `portal_revision`
- [ ] Payload contains **only** intended public data — no IPs, hostnames, versions, ports, credentials, stack traces, env data, Docker details, raw monitoring payloads
- [ ] Frontend graceful degradation confirmed (stale/missing file)

**Acceptance:** `curl /status/status.json` shows the sanitized schema; homepage tiles update; stale-file case degrades gracefully. *(Deferred — placeholder is live in the meantime.)*

### S5. Skills Runner `publish_file` *(brief Phase 6)*
- [ ] Add only the confirmed public dir as an RW mount (e.g. `/data/media/public:/public`)
- [ ] Implement `publish_file(source_path, destination_name?, subdirectory="ai", overwrite=false)` → `{path, url, size_bytes, sha256}`
- [ ] Validate: reject absolute paths, `..` traversal, null bytes, symlinks, special files; restrict source roots; temp-file-then-rename atomic write; sane modes (world-readable, non-executable); collision-safe names; active-web-type block/force-download; local logging only
- [ ] Unit tests for validation + integration test publishing a sample PDF/image

**Acceptance:** skill returns the correct public URL; a published file appears under `/files/` immediately; all rejection cases tested.

### S6. Security + functional test matrix *(brief Phase 7)*
- [ ] Routes: `/`, `/arcade/`, `/thoughts/`, `/lab/`, `/files/`, nested `/files/` dirs
- [ ] Git update appears atomically via git-sync; public file appears without a site rebuild
- [ ] Invalid paths: `../`, encoded traversal, absolute paths, dotfiles, long names, collisions
- [ ] Symlink file + symlink directory attempts (publish rejected; manual symlink can't escape the root)
- [ ] Blocked/forced-download active content behavior
- [ ] Direct requests for known private sibling paths fail; portal container cannot write its mounts; no container has more access than required
- [ ] Mobile viewport, keyboard navigation, reduced-motion, missing status JSON

**Acceptance:** full matrix results recorded in `IMPLEMENTATION_NOTES.md`; every failure fixed or explicitly deferred.

### S7. Cutover + cleanup *(brief Phase 8)*
- [ ] Capture the pre-cutover rollback procedure (how to point the existing Caddy route back at Ghost)
- [ ] Switch the existing Caddy route: `choukalos.com` → portal origin (only that route changes; Cloudflare tunnel untouched)
- [ ] Validate externally over HTTPS from outside the LAN: landing, arcade (all 7 games), a git-published post, `/files/`, a published test file, status placeholder, logs/cache behavior
- [ ] Stop Ghost (keep its data); after the rollback window, remove unused Ghost runtime per the homelab backup policy

**Acceptance:** external validation checklist passes; rollback documented and testable; Ghost stopped (data retained).

---

## Ordering & dependencies

```
Part A (laptop)                    Part B (server, DRAFT)
──────────────────                 ─────────────────────
A0 tooling + repo ──────────────┐
A1 scaffold + arcade             │
A2 theme                         │  S0 discovery on thor (independent; revises Part B)
A3 homepage modules              │  S1 filesystem boundaries (independent)
A4 authoring + deploy.sh         │  S2 Caddy + /files/ (independent; placeholder content OK)
A5 local validation + docs       │  S3 git-sync (NEEDS: A0 GitHub push + deploy branch)
                                 │  S4 status publisher (DEFERRED)
                                 │  S5 Skills Runner (independent)
                                 │  S6 test matrix (NEEDS: A5 + S2–S3, S5)
                                 │  S7 cutover (NEEDS: Part A done + S6 passed)
```

- **Parallelizable:** A1–A4 runs alongside S0–S2, S5 (server work doesn't need the final theme).
- **Hard gates:** S3 needs the repo on GitHub + a `deploy` branch (A0/A4). S6/S7 need both parts substantially complete.
- **Ghost stays up** through all of Part B until S7's external validation passes.

## 4. Cross-cutting acceptance (from brief §11)

**Functional**
- Portal home loads from the public hostname; all sections work on desktop and mobile
- Arcade runs under `/arcade/` with assets intact (7 games)
- A Markdown thought committed to Git appears after deploy sync without touching the web server
- A PDF published via Skills Runner is visible under `/files/` with the correct returned URL
- `/files/` matches the portal visual language and works without JavaScript
- Status tiles update from sanitized `status.json` and degrade gracefully when stale/missing *(deferred — placeholder acceptance applies until S4)*
- Caddy has read-only access to site content, runtime status, and public files

**Security**
- Traversal (`../`, encoded) cannot escape the public roots
- Symlink publishing rejected; manual symlink can't expose data outside the root
- Skills Runner cannot publish arbitrary host paths outside approved source roots
- Active file types in the drop zone follow the block/force-download policy
- No Docker socket, credentials, env dumps, private monitoring payloads, internal addresses/hostnames in public responses
- Origin exposes only the expected port/network path from the existing edge

**Operations**
- git-sync recovers from a temporary Git outage without manual intervention
- A bad portal change rolls back via Git revert + `deploy.sh` or deploy-ref change
- Public files can be removed without modifying the site repo
- Local logs available for Caddy, git-sync, status publishing, `publish_file`
- Migration notes document how to restore the old Ghost route

**Definition of done:** migration is complete only when every item above is demonstrated or explicitly documented as deferred with a reason.