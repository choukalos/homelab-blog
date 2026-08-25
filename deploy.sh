#!/usr/bin/env bash
# Build the site locally and publish the built output to the deploy branch.
#
#   ./deploy.sh
#   DEPLOY_BRANCH=deploy ./deploy.sh
#
# The laptop is the only build machine: the server (git-sync) consumes the
# deploy branch and never runs Hugo.
set -euo pipefail
cd "$(dirname "$0")"

BRANCH="${DEPLOY_BRANCH:-deploy}"
HUGO="${HUGO:-hugo}"

echo "→ building site (hugo --minify --gc)..."
"$HUGO" --minify --gc

ORIGIN_URL="$(git remote get-url origin)"
if [[ -z "$ORIGIN_URL" ]]; then
  echo "error: no 'origin' remote. Create the GitHub repo and: git remote add origin <url>" >&2
  exit 1
fi

# Temp clone of the deploy branch (created on first run).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The temp repo is a fresh git repo — inherit this repo's identity.
GIT_NAME="$(git config user.name)"
GIT_EMAIL="$(git config user.email)"

if git ls-remote --exit-code --heads "$ORIGIN_URL" "$BRANCH" >/dev/null 2>&1; then
  git clone -q --branch "$BRANCH" --single-branch --depth 1 "$ORIGIN_URL" "$TMP/site"
else
  echo "→ deploy branch '$BRANCH' doesn't exist on origin yet — creating it..."
  git init -q -b "$BRANCH" "$TMP/site"
  git -C "$TMP/site" remote add origin "$ORIGIN_URL"
fi

# Replace contents with the fresh build.
find "$TMP/site" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R public/. "$TMP/site/"

git -C "$TMP/site" add -A
REVISION="$(git rev-parse --short HEAD)"
git -C "$TMP/site" -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" \
  commit -q -m "deploy: portal build from main@$REVISION ($(date -u +%FT%TZ))"
git -C "$TMP/site" push -q origin "$BRANCH"

echo "✓ deployed main@$REVISION → origin/$BRANCH"
echo "  server (git-sync) will pick it up within its sync period (~30s)"