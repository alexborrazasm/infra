#!/usr/bin/env bash
# Create a Headscale API key (what you type to log in to Headplane).
#   ./headscale-apikey.sh          expires in 90d
#   ./headscale-apikey.sh 30d      custom expiration
# The key is shown once: save it in your password manager. Put it next to
# compose.yml.
set -euo pipefail
cd "$(dirname "$0")"

SERVICE="${SERVICE:-headscale}"
EXPIRATION="${1:-90d}"

echo "🔑 Creating API key for Headplane (expires in $EXPIRATION)..."
docker compose exec "$SERVICE" headscale apikeys create --expiration "$EXPIRATION"
echo "⚠️  Shown only once, save it now."
