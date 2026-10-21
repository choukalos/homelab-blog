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
- **Status panel** on the homepage: a few friendly service tiles, no internals. A tiny `statusd` sidecar on the server publishes a sanitized `/status/status.json` every 30s (see `architecture.md` §6.3).

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

## Requirements

- **Hugo ≥ v0.168.0 (extended)** on the laptop — the only build machine. v0.168.0 (2026-10-13) fixes GHSA-r73q-gwx2-fpxm (theme `module.replacements` mount-sandbox bypass) and is current as of this note. Check `hugo version` and the [Hugo security advisories](https://github.com/gohugoio/hugo/security/advisories) before building.

## Owner quickstart

| Task | How |
|---|---|
| Write a post | `scripts/new-thought.sh "my-post"` → edit the created file → `hugo server` to preview |
| Update Hugo | download the latest `hugo_extended_*_darwin-universal.pkg` from the [releases](https://github.com/gohugoio/hugo/releases), verify the SHA256 against `hugo_*_checksums.txt`, and replace `~/bin/hugo` (the laptop is the only build machine) |
| Preview locally | `hugo server` → http://localhost:1313 |
| Publish a page | `git push` to `main`, then `./deploy.sh` |
| Publish a file | `publish_file` skill on the server (returns the public URL) |
| Remove a file | Delete/move the file from the public drop dir — no site change needed |
| Roll back the site | `git revert` + push + `./deploy.sh` (or point git-sync at an older `deploy` revision) |

## Status

✅ **Portal live at https://choukalos.com.** Part A (laptop) is complete: Hugo site, cyberpunk/brick theme, arcade, homepage modules, and `deploy.sh` per `PLAN.md`. Part B (server) has been executed on `thor`: Caddy origin, git-sync, the `statusd` status publisher, Skills Runner, and cutover (Ghost is no longer the live site). The status pipeline is documented in `architecture.md` §6.3.

## Docs

- [`architecture.md`](architecture.md) — full architecture, human- and AI-readable (components, data flows, security boundaries, decisions log, invariants)
- [`PLAN.md`](PLAN.md) — two-part phased implementation plan: **Part A** (laptop) and **Part B** (server, draft)
- [`IMPLEMENTATION_NOTES.md`](IMPLEMENTATION_NOTES.md) — discovered assumptions, changes, test results, rollback steps
- [`docs/brief/`](docs/brief/) — the original implementation brief this project is built from