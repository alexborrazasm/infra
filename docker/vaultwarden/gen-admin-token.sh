#!/usr/bin/env bash
# Generate a Vaultwarden admin token and its argon2 hash.
#   ./gen-admin-token.sh              random token
#   ./gen-admin-token.sh "my phrase"  hash a password of your choice
# Prints the plain token (what you type in /admin; keep it in your password
# manager) and the ADMIN_TOKEN line for the env file. Nothing is written to
# disk. Needs the argon2 CLI (dnf install argon2).
set -euo pipefail

command -v argon2 >/dev/null || { echo "argon2 not found (dnf install argon2)" >&2; exit 1; }

token="${1:-$(openssl rand -base64 48)}"
hash="$(printf '%s' "$token" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)"

echo "Token (admin login, keep it safe):"
echo "$token"
echo
echo "For the env file (env_file: single quotes, \$ stays as is):"
echo "ADMIN_TOKEN='$hash'"
