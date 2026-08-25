#!/usr/bin/env bash
# Scaffold a new thought post: scripts/new-thought.sh "my-post-slug"
set -euo pipefail
cd "$(dirname "$0")/.."

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "usage: scripts/new-thought.sh <slug>" >&2
  exit 1
fi
SLUG="$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"

DATE="$(date +%F)"
FILE="content/thoughts/${DATE}-${SLUG}.md"
if [[ -e "$FILE" ]]; then
  echo "already exists: $FILE" >&2
  exit 1
fi

cat > "$FILE" <<EOF
---
title: "New Thought"
date: ${DATE}
draft: true
tags: []
summary: "One-line teaser shown on the homepage."
---

Write it here.
EOF

echo "created $FILE (draft — set draft: false to publish)"