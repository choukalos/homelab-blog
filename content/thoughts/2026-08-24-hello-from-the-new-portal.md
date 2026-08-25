---
title: "Hello from the new portal"
date: 2026-08-24
draft: false
tags: [homelab, migration]
summary: "The old Ghost blog is being retired. This is the new static, git-published portal — and the first post on it."
---

This site is replacing the old Ghost blog. The new design is deliberately boring to operate:

- **Pages and posts** are Markdown in a Git repo. A `git push` plus a one-command build is the entire publishing workflow.
- **The arcade** lives here as self-contained HTML games — no build step, no dependencies.
- **Ad-hoc files** (AI output, media) go into a public drop zone and appear under `/files/` instantly, without touching this repo.
- **Status** on the homepage comes from a small sanitized JSON feed — no internal details, no Docker socket, no telemetry.

No CMS database, no admin UI, no plugin ecosystem. If the site is down, it's because the server is down, and that's fixable with one `docker compose up`.

First post. More to come.