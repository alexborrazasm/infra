#!/usr/bin/env bash
# Format the Caddyfile and reload Caddy without downtime. Put it next to
# compose.yaml. If the config is invalid, reload fails and Caddy keeps
# running with the previous one.
set -euo pipefail
cd "$(dirname "$0")"

SERVICE="${SERVICE:-caddy}"

if [ -t 1 ]; then
  dim=$'\e[2m'; red=$'\e[31m'; green=$'\e[32m'; bold=$'\e[1m'; off=$'\e[0m'
else
  dim=""; red=""; green=""; bold=""; off=""
fi

# Run a step quietly; show Caddy's own output only if it fails.
step() {
  local label="$1"; shift
  local start=$SECONDS out
  printf '%s' "$label"
  if out="$("$@" 2>&1)"; then
    printf ' %s✔%s %s(%ss)%s\n' "$green" "$off" "$dim" "$((SECONDS - start))" "$off"
  else
    printf ' %s✘%s\n\n%s%s%s\n' "$red" "$off" "$red" "$out" "$off" >&2
    exit 1
  fi
}

echo "${bold}🔧 Caddy reload${off} ${dim}($SERVICE)${off}"
step "  🔹 formatting Caddyfile " docker compose exec -w /etc/caddy "$SERVICE" caddy fmt --overwrite
step "  🔍 validating config    " docker compose exec -w /etc/caddy "$SERVICE" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
step "  🔄 reloading            " docker compose exec -w /etc/caddy "$SERVICE" caddy reload
echo "${green}${bold}✅ Done, Caddy is running the new config${off}"
