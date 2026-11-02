#!/usr/bin/env bash
# Create a private CA in $PKI_DIR (default: <repo>/pki). Run once.
#   scripts/ca-new.sh "CA common name"
# ca.crt is public: hand it to clients. ca.key must never leave this machine.
set -euo pipefail

PKI_DIR="${PKI_DIR:-$(cd "$(dirname "$0")/.." && pwd)/pki}"
CA_DAYS="${CA_DAYS:-3650}"

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 \"CA common name\"" >&2
  echo "  e.g. $0 \"Alboman CA\"" >&2
  exit 1
fi
CA_CN="$1"

if [ -e "$PKI_DIR/ca.key" ]; then
  echo "CA already exists in $PKI_DIR, refusing to overwrite it" >&2
  exit 1
fi

umask 077
mkdir -p "$PKI_DIR"

openssl genrsa -out "$PKI_DIR/ca.key" 4096
openssl req -x509 -new -key "$PKI_DIR/ca.key" -sha256 -days "$CA_DAYS" \
  -subj "/CN=$CA_CN" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash" \
  -out "$PKI_DIR/ca.crt"
chmod 644 "$PKI_DIR/ca.crt"

echo "CA created: $PKI_DIR/ca.crt (public), $PKI_DIR/ca.key (secret)"
