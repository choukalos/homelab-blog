# Homelab Portal

A public, static, Git-published portal for the homelab at **https://choukalos.com** — replacing the Ghost CMS with something a single owner can run without thinking about it.

**One sentence:** permanent content publishes with `git push`; ad-hoc files (AI output, media) publish by dropping them in a public folder — and the web server itself can change almost nothing.

---

## Why

Ghost was the wrong shape for a one-person site: a CMS database, admin UI, theme/plugin ecosystem, and a dynamic runtime — all public-facing maintenance for content I alone will write. The new design is:

- **Static site (Hugo)** for everything authored: landing page, arcade, lab projects, thoughts (the blog).
- **Caddy** as a dumb origin server: serves built files, nothing else.
- **git-sync** pulls a `deploy` branch and atomically swaps the site — a push is a deploy.
- **Public drop zone** (`/files/`) for shareable artifacts that should be live *now*, without a commit or rebuild.
- **Status panel** on the homepage: a few friendly service tiles, no internals (publisher deferred — placeholder for now).

Result: no database, no admin UI, no plugin surface, tiny attack surface, and publishing workflows that are just `git push` and `cp`.

## What's on the site

| Route | What it is | How it publishes |
|---|---|---|
| `/` | Landing page: status, arcade, latest drop, recent thoughts | Git → Hugo |
| `/arcade/` | Themed arcade index (maker, year, details, screenshots) + one-page HTML games | Git (static) |
| `/thoughts/` | Occasional posts / notes — the blog | Git → Hugo |
| `/lab/` | Projects, experiments, builds | Git → Hugo |
| `/files/` | Themed browser for public files (AI output, media) — server-side | File drop, live instantly |

The look is a retro-futurist home base: dark surfaces, neon accents, chunky "brick-built" module cards, restrained arcade motion — accessible and mobile-first.

## How publishing works

**Curated content (this repo):**

```
write Markdown on the laptop → hugo server (preview) → commit → push to main
  → ./deploy.sh (Hugo build on the laptop) → deploy branch → git-sync on the server → live (no restart)
```

The server never runs a build: it receives only finished HTML/CSS/JS.

**Ad-hoc files (server):**

```
Skills Runner publish_file() (or a manual copy) → public drop dir → live under /files/
```

## Owner quickstart

| Task | How |
|---|---|
| Write a post | `scripts/new-thought.sh "my-post"` → edit the created file → `hugo server` to preview |
| Preview locally | `hugo server` → http://localhost:1313 |
| Publish a page | `git push` to `main`, then `./deploy.sh` |
| Publish a file | `publish_file` skill on the server (returns the public URL) |
| Remove a file | Delete/move the file from the public drop dir — no site change needed |
| Roll back the site | `git revert` + push + `./deploy.sh` (or point git-sync at an older `deploy` revision) |

## Status

🚧 **Migration in progress — Part A (laptop) underway.** The Hugo site, cyberpunk/brick theme, arcade merge (7 games), homepage modules, and `deploy.sh` are in this repo per `PLAN.md` Part A. Server work (Caddy origin, git-sync, status publisher, Skills Runner, cutover) is **Part B — draft**, to be firmed up by discovery on the server before execution. Ghost stays up until the new portal passes external validation.

## Docs

- [`architecture.md`](architecture.md) — full architecture, human- and AI-readable (components, data flows, security boundaries, decisions log, invariants)
- [`PLAN.md`](PLAN.md) — two-part phased implementation plan: **Part A** (laptop) and **Part B** (server, draft)
- [`IMPLEMENTATION_NOTES.md`](IMPLEMENTATION_NOTES.md) — discovered assumptions, changes, test results, rollback steps
- [`docs/brief/`](docs/brief/) — the original implementation brief this project is built from