# Homelab Portal — Architecture

> **Status:** v0.2 (2026-08-24) — owner decisions resolved; Part B (server) is a **draft pending discovery on `thor`**.
> **Source of truth:** `docs/brief/homelab_portal_implementation_brief.pdf` + laptop/server inventory.
> **Audience:** humans (owner, future readers) AND AI agents (stable section numbers, tables, explicit invariants, copy-pasteable commands in §13).

---

## 1. One-paragraph summary

The public homelab site at **https://choukalos.com** replaces Ghost (a dynamic CMS) with a **static, Git-managed portal** plus a **public file drop zone**. Authored pages (landing, arcade, lab, thoughts) are Markdown/HTML in a Git repo, **built on the dev laptop by Hugo**, and published by pushing the built site to a `deploy` branch that `git-sync` pulls atomically on the server; Caddy serves the result read-only. Ad-hoc artifacts (AI-generated PDFs, images, audio, video) are copied by the Skills Runner into a dedicated public directory that Caddy also serves read-only under a themed `/files/` browser. A small status publisher (deferred) writes a sanitized `status.json` consumed by the homepage. The Internet-facing server is "dumb": it serves, and changes almost nothing.

## 2. Design goals

1. **Two publishing paths, both boring:** `git push` for curated content; file copy/skill for ad-hoc files. No CMS, no database, no admin UI, no plugin ecosystem.
2. **Small public attack surface:** static files only; no dynamic runtime for normal page delivery.
3. **Explicit security boundary:** only the explicit public directory is Internet-visible. The filesystem mount *is* the boundary (not `hide` rules).
4. **Feels like a personal arcade/lab console:** retro-futurist, neon-on-dark, brick-built modules, arcade motion — without sacrificing readability or accessibility.
5. **Agent-friendly:** a narrow `publish_file` capability returns a public URL; the repo/docs are readable by an AI agent doing the server-side work.

## 3. Machine split (read this first)

| Machine | Host | Role | What lives here |
|---|---|---|---|
| **Dev laptop** (this machine, arm64 Mac) | `chuck`'s MacBook | Authoring, **build**, preview, git | Hugo source repo (this directory), local `hugo server` preview, `deploy.sh` (build + publish), arcade source |
| **Server** | `thor` (x86) | Hosting | Caddy origin (internal port), git-sync, status publisher (deferred), Skills Runner, `/homelab/data/...` storage |

**Edge path (kept as-is):** Internet → **Cloudflare** (DNS + tunnel) → **existing Caddy reverse proxy on thor** → upstreams. The new static origin is a *new upstream* behind the existing Caddy; cutover = re-pointing the `choukalos.com` route from the Ghost upstream to the portal origin upstream. No new TLS ingress, no new public ports.

**Rule of thumb:** anything that produces *source or built output* happens on the laptop; anything that *serves or publishes* happens on thor. The only thing crossing the boundary is Git.

## 4. High-level diagram

```
                 INTERNET
                    |
        Cloudflare (DNS + tunnel)          (kept as-is)
                    |
        existing Caddy reverse proxy on thor   (kept as-is; route re-pointed at cutover)
                    |
                    v
        +---------------------+
        |  NEW CADDY ORIGIN   |  static serving, internal port only
        |  (read-only mounts) |
        +-----+-----+-----+---+
              |     |     |
   / /arcade  |     |     |  /files/*        /status/*
   /thoughts  |     |     |
   /lab       |     |     v
              v     v  +---------------------------+
   +------------------+  | /homelab/data/media/    |
   | git-sync          |  | public/   (drop zone)   |
   | current -> worktree|  +-----------^-------------+
   +--------^---------+                |
            |  pulls (30s)             | writes (publish_file)
            v                          |
   GitHub: homelab-blog repo   Skills Runner on thor
   (main = source, deploy = built site)
            ^
            | deploy.sh: hugo --minify → push built site
            |
   +--------+----------------------+
   | LAPTOP: this repo (Hugo src)  |
   | content/ layouts/ static/     |
   | hugo.toml  deploy.sh          |
   +-------------------------------+
        |
   status publisher (thor, DEFERRED) ---> /homelab/data/public-site/runtime/status.json
        (sanitized, every 30-60s, read-only to Caddy)
```

## 5. Components

### 5.1 Laptop side (this repo)

| Component | Purpose | Notes |
|---|---|---|
| Hugo source repo | All authored content + theme + static assets | Public GitHub repo `homelab-blog`; `main` branch = source |
| `content/thoughts/` | Blog posts / notes (Markdown) | The "simpler blog" |
| `content/lab/` | Projects, experiments, builds | Markdown pages |
| `static/arcade/` | One-page arcade games + themed index | Merged from `~/Code/one-page-arcade/`; games are self-contained HTML, no build step |
| `data/arcade/games.json` | Arcade metadata (title, company, year, description, file, screenshot) | Drives the `/arcade/` index cards |
| `layouts/` + `assets/` | Cyberpunk/brick theme, CSS tokens, partials | No external CDN deps |
| `deploy.sh` | Build (`hugo --minify --gc`) + push built site to `deploy` branch | Laptop is the build machine |

**Build decision (owner, 2026-08-24):** build on the laptop, push to GitHub; the `deploy` branch is what the server consumes. This deviates from the brief's *primary* CI-build recommendation but satisfies its hard requirement (no build tooling in the Internet-facing container). GitHub Actions is a drop-in replacement later if desired.

### 5.2 Server side (thor) — DRAFT, pending discovery

| Component | Responsibility | Write access |
|---|---|---|
| Caddy (`portal` container) | Serve generated site, themed `/files/` browse, `/status/`, headers/compression | None (all content mounts read-only) |
| git-sync v4 | Pull `deploy` branch, atomically switch `current` symlink | Only its deployment volume |
| status publisher | Produce sanitized `status.json` on a schedule — **deferred (placeholder now)** | Only runtime status dir |
| Skills Runner (real component on thor) | `publish_file` into the public drop zone | Only the public media dir (for publishing) |
| existing Caddy reverse proxy | TLS-terminating upstream routing behind the Cloudflare tunnel (unchanged) | — |

**Out of scope / untouched:** the internal family portal (`~/Code/internal-homelab-portal`, Node/Express, LAN-only) stays as-is — different system (internal, dynamic, Grafana-embedded). Public Grafana on thor is a **future** status source (deferred).

## 6. Data flows

### 6.1 Curated content (git push → live)

1. Edit content/theme on the laptop; `hugo server` preview at `http://localhost:1313`.
2. Commit + push to `main` (source of record).
3. `./deploy.sh` builds Hugo (pinned version) and pushes the **generated static output** to the `deploy` branch.
4. git-sync on thor pulls `deploy` every ~30s and atomically updates `current` (worktree + symlink; consumers never see a partial checkout).
5. Caddy serves `current` read-only. No Caddy restart on deploy.

**Why a deploy branch:** the public origin receives only built HTML/CSS/JS. Hugo, source deps, and build tooling never exist on the server at all.

### 6.2 Ad-hoc files (drop → live)

1. Skills Runner (or a manual `cp` on thor) places a file in the public drop dir (`ai/`, `images/`, `audio/`, `video/`, `files/`).
2. Caddy's themed `/files/` browse template shows it immediately — no git commit, no rebuild.
3. `publish_file` skill returns `{path, url, size_bytes, sha256}`.

### 6.3 Status panel — **deferred (placeholder)**

- **Now:** homepage SYSTEM STATUS module renders a graceful placeholder ("status service offline — check back soon") when `/status/status.json` is missing/stale. No publisher exists yet.
- **Later:** status publisher on thor (30–60s schedule; reads existing monitoring — e.g. the public Grafana — or explicitly configured health checks; maps to friendly names + coarse states `online`/`degraded`/`offline`; atomic write to the runtime dir; Caddy serves read-only).

Example payload (target shape — services TBD when implemented):

```json
{
  "overall": "online",
  "updated_at": "2026-08-24T15:00:00Z",
  "portal_revision": "a1b2c3d",
  "services": [
    {"name": "AI Lab", "state": "online"},
    {"name": "Media", "state": "online"},
    {"name": "Public Files", "state": "online"}
  ]
}
```

## 7. Repository layout (laptop)

```
homelab-blog/                      # public GitHub repo
├── hugo.toml                      # site config (baseURL https://choukalos.com/)
├── deploy.sh                      # build + publish to deploy branch
├── scripts/
│   └── new-thought.sh             # scaffold a new post
├── content/
│   ├── thoughts/                  # posts: YYYY-MM-DD-slug.md
│   └── lab/                       # projects: slug.md
├── data/
│   └── arcade/games.json          # arcade metadata (drives /arcade/ index)
├── layouts/
│   ├── index.html                 # landing page (status/arcade/drop/thoughts modules)
│   ├── _default/                  # baseof, single, list
│   ├── arcade/index.html          # themed arcade cabinet listing
│   └── partials/                  # header, footer, nav, status
├── assets/
│   ├── css/main.css               # tokens + theme (brick/neon)
│   └── js/status.js               # status fetch (progressive enhancement)
├── static/
│   ├── arcade/                    # merged from ~/Code/one-page-arcade/
│   │   ├── *.html                 # 7 games (self-contained)
│   │   └── shots/                 # screenshots (capture pending)
│   └── images/
├── docs/
│   └── brief/                     # the implementation brief PDF
├── architecture.md                # this file
├── README.md                      # exec view
├── PLAN.md                        # two-part phased implementation plan
└── IMPLEMENTATION_NOTES.md        # discovered assumptions, changes, tests, rollback
```

## 8. Content model

| Route | Purpose | Publishing model |
|---|---|---|
| `/` | Portal landing + status placeholder + arcade/drop/thoughts modules | Git / Hugo |
| `/arcade/` | Themed arcade index (cards: screenshot, title, maker, year, description) + one-page HTML games | Git / Hugo index + static game files |
| `/thoughts/` | Occasional Markdown posts / notes | Git / Hugo |
| `/lab/` | Projects, experiments, builds | Git / Hugo |
| `/files/` | Themed browseable public file index (server-side) | Shared public mount (Caddy browse) |
| `/files/ai/` | Agent/skill-generated artifacts | Skills Runner writes |

**Arcade roster (owner decision 2026-08-24):** 7 games — asteroids, galaga, missile-command, tetris, depth-charge, elite, lunar-lander. **Excluded:** `joust.html` (broken), `rolling-thunder.html` (deprioritized). More games will be added later — the index is data-driven (`data/arcade/games.json`) so adding a game = drop the HTML file + add a JSON entry.

**Front-matter conventions (thoughts posts):**

```yaml
---
title: "Post title"
date: 2026-08-24
draft: false            # drafts never publish
tags: [homelab, caddy]
summary: "One-line teaser for the homepage RECENT THOUGHTS module"
---
```

**Nav labels read like console modules:** `ARCADE`, `LAB`, `THOUGHTS`, `FILES`.

## 9. Server deployment shape (DRAFT — adapt to thor's existing conventions)

> The server-side agent (pi run on thor) must **inspect first** (existing compose, networks, UID/GID, proxy labels, secrets, the existing Caddy reverse proxy behind the Cloudflare tunnel) and adapt; this is a target shape, not copy/paste gospel. Part B of `PLAN.md` is the working draft.

### 9.1 Filesystem layout on thor (target)

```
/homelab
├── apps/public-site/
│   ├── compose.yaml
│   ├── Caddyfile
│   ├── browse-template.html       # themed /files/ listing
│   └── env.example
└── data/
    ├── public-site/
    │   ├── git/                   # git-sync worktrees + `current` symlink
    │   └── runtime/
    │       └── status.json        # (deferred)
    └── media/
        └── public/                # ONLY this subtree is public
            ├── ai/  files/  images/  audio/  video/
```

### 9.2 Mount policy

| Consumer | Host path | Container path | Mode |
|---|---|---|---|
| Caddy | `/homelab/data/public-site/git` | `/srv/git` | ro |
| Caddy | `/homelab/data/public-site/runtime` | `/srv/runtime` | ro |
| Caddy | `/homelab/data/media/public` | `/srv/files` | ro |
| git-sync | `/homelab/data/public-site/git` | `/git` | rw |
| status publisher | `/homelab/data/public-site/runtime` | `/status` | rw |
| Skills Runner | `/homelab/data/media/public` | `/public` | rw |

### 9.3 Caddyfile (target shape)

```caddy
:8080 {                                   # internal-only port (TBD on thor)
    encode zstd gzip

    # Public file drop (mounted read-only; template matches portal theme)
    handle_path /files/* {
        root * /srv/files
        file_server browse /etc/caddy/browse-template.html {
            sort namedirfirst asc
        }
    }

    # Sanitized status output (deferred)
    handle_path /status/* {
        root * /srv/runtime
        file_server
    }

    # Generated Hugo site via git-sync's atomic symlink
    handle {
        root * /srv/git/current
        file_server
    }
}
```

### 9.4 Compose (target shape)

```yaml
services:
  portal:            # caddy:<PINNED_VERSION>
    read_only: true
    tmpfs: [/config, /data]
    ports: ["127.0.0.1:<ORIGIN_PORT>:8080"]   # or internal network only
    volumes: [Caddyfile ro, browse-template ro, git ro, runtime ro, media/public ro]
  git-sync:          # registry.k8s.io/git-sync/git-sync:<PINNED_V4>
    env: [GITSYNC_REPO=<github.com/<owner>/homelab-blog>, GITSYNC_REF=deploy,
          GITSYNC_ROOT=/git, GITSYNC_LINK=current, GITSYNC_PERIOD=30s]
    volumes: [/homelab/data/public-site/git:/git]
  status-publisher:  # deferred
```

**git-sync v4 notes:** current docs use `--link` (not `--dest`) and `--period` (not `--wait`); publishes via worktree + symlink for atomic consumption. Repo is public → no deploy key needed (revisit if the repo goes private).

## 10. Security boundaries (non-negotiable)

1. **Mount is the boundary.** Never rely on Caddy `hide` rules; only the explicit public directory is mounted into the web container.
2. **No symlink escape.** Caddy's file root is *not* a sandbox against symlinks pointing outside the root → prevent symlinks in the public drop dir; `publish_file` rejects symlinks and special files.
3. **No Docker socket** in the portal container. Status comes from the sanitized publisher, never from Docker inspection.
4. **Read-only Git credentials** if the repo ever goes private (deploy key preferred).
5. **Active-content rule:** curated HTML/JS belongs in Git. The drop zone blocks or force-downloads active web types (`.html`, `.htm`, `.js`). (Future: AI-generated live demos only on a separate sandbox origin with restrictive CSP.)
6. **Sanitized status only.** Never expose: internal IPs/hostnames, container names, versions, ports, CPU/RAM telemetry, private URLs, Docker events, stack traces, tokens, env vars, raw monitoring payloads.
7. **Non-root containers** where practical; explicit UID/GID ownership on shared mounts.
8. **Drop zone = untrusted display content**, even when generated by your own AI.
9. **No new public ports** — the existing edge (Cloudflare tunnel + thor Caddy) routes to the internal origin.

## 11. Operations (steady state)

| Task | Command / action |
|---|---|
| Write a post | `scripts/new-thought.sh "slug"` → edit → `hugo server` preview |
| Preview locally | `hugo server` → http://localhost:1313 |
| Publish (pages + arcade) | `git push` to `main`, then `./deploy.sh` (build + push `deploy` branch) |
| Publish a file (agent) | `publish_file(source, dest_name?, subdir="ai")` on thor → returns public URL |
| Publish a file (manual) | `cp file <public-drop-dir>/<subdir>/` on thor |
| Remove a file | move/delete from the public drop dir (no site rebuild needed) |
| Rollback the site | `git revert` + push + `./deploy.sh` (or point git-sync at an older `deploy` revision) |
| Restore old Ghost | re-point the thor Caddy route back to the Ghost upstream (Ghost retained during rollback window) |

## 12. Decisions log

**Resolved (owner, 2026-08-24):**

| # | Decision | Resolution |
|---|---|---|
| 1 | Repo | Public GitHub, named `homelab-blog` |
| 2 | Build | Laptop builds (Hugo pinned binary, darwin-arm64 in `~/bin`); `deploy.sh` pushes built site to `deploy` branch; server never builds. (Brief's CI recommendation superseded by owner choice; hard requirement "no build in public container" still met.) |
| 3 | Hostname | `https://choukalos.com` (same as current Ghost) |
| 4 | Edge | Cloudflare tunnel + existing Caddy reverse proxy on thor — kept as-is; new origin is a new upstream; cutover re-points the route |
| 5 | Arcade | 7 games (drop joust — broken; rolling-thunder — meh); `one-page-arcade` folder merged into this repo; themed index page with screenshots + maker/year/details; more games later |
| 6 | Ghost migration | Start fresh (no post migration) |
| 7 | Status panel | Placeholder now; publisher + Grafana integration deferred to a later phase |
| 8 | Skills Runner | Real component on thor — `publish_file` proceeds as planned |
| 9 | Part B execution | Draft now; owner will run pi on thor to discover actual architecture and firm up Part B before server work begins |
| 10 | Hugo install | Prebuilt binary (no Homebrew); laptop arm64, server x86 — binary choice only matters on the laptop |
| 11 | Git identity | `Chuck Choukalos <chuck@Chucks-MacBook-Air.local>` (from existing repos; confirm) |

**Remaining `[TBD]`:**

| # | Item | Notes |
|---|---|---|
| a | `deploy` branch name | default `deploy` |
| b | Arcade screenshots | capture via headless browser (task in PLAN A1) |
| c | Part B specifics | all of it — discovery on thor (PLAN Part B) |
| d | Git identity confirmation | see decision 11 |

## 13. AI agent operating notes

**Repo commands (laptop):**

```bash
hugo server -D            # local preview with drafts (http://localhost:1313)
hugo --gc --minify        # production build check
./deploy.sh               # build + push built site to deploy branch
scripts/new-thought.sh "my-post-slug"   # scaffold a new post
```

**Invariants (never violate):**

- Do not commit secrets, real internal hostnames/IPs, or monitoring internals into this repo or generated examples.
- Do not put AI-generated executable HTML/JS into the site via the drop-zone path; arcade games in `static/arcade/` are curated (Git-managed) and are the exception.
- Do not add runtime CDN dependencies to `layouts/`/`assets/` (no external fonts/JS either).
- Keep `content/thoughts/` files self-contained Markdown (no Ghost shortcodes).
- Arcade games are self-contained single-file HTML — copy, don't rewrite.
- The server-side agent (pi on thor) must inspect thor before editing (compose, networks, UID/GID, the existing Caddy reverse proxy config, Cloudflare tunnel setup) and record findings in `IMPLEMENTATION_NOTES.md`.

**Server-side handoff:** `PLAN.md` Part B is the draft phase list for the thor agent (S0–S8, mirroring the brief's Phase 0–8). The brief's "Qwen execution prompt" sections apply verbatim to that agent. Part B will be revised on thor after S0 discovery.

**Definition of done:** see `PLAN.md` §4 (acceptance) and the brief §11. Migration is complete only when every acceptance item is demonstrated or explicitly deferred with a reason.