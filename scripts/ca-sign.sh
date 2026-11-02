#!/usr/bin/env bash
# Issue a server certificate signed by the CA from ca-new.sh.
#   scripts/ca-sign.sh <name> [<name>...]
# Each name is a DNS name or an IP; all of them go into the SAN (clients
# check the SAN, not the CN). The first one names the output directory:
#   $PKI_DIR/<first-name>/{<first-name>.crt,<first-name>.key}
set -euo pipefail

PKI_DIR="${PKI_DIR:-$(cd "$(dirname "$0")/.." && pwd)/pki}"
DAYS="${DAYS:-825}"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <dns-or-ip> [<dns-or-ip>...]" >&2
  exit 1
fi
for f in ca.crt ca.key; do
  [ -f "$PKI_DIR/$f" ] || { echo "missing $PKI_DIR/$f, run ca-new.sh first" >&2; exit 1; }
done

NAME="$1"
OUT="$PKI_DIR/$NAME"
if [ -e "$OUT/$NAME.key" ]; then
  echo "$OUT/$NAME.key already exists, refusing to overwrite it" >&2
  exit 1
fi

san=""
for n in "$@"; do
  if [[ "$n" =~ ^[0-9.]+$ || "$n" == *:* ]]; then kind=IP; else kind=DNS; fi
  san="${san:+$san,}$kind:$n"
done

umask 077
mkdir -p "$OUT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/ext" <<EXT
subjectAltName=$san
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EXT

openssl genrsa -out "$OUT/$NAME.key" 2048
openssl req -new -key "$OUT/$NAME.key" -subj "/CN=$NAME" -out "$tmp/csr"
openssl x509 -req -in "$tmp/csr" -CA "$PKI_DIR/ca.crt" -CAkey "$PKI_DIR/ca.key" \
  -CAserial "$PKI_DIR/ca.srl" -CAcreateserial \
  -days "$DAYS" -sha256 -extfile "$tmp/ext" -out "$OUT/$NAME.crt"
chmod 644 "$OUT/$NAME.crt"

echo "Issued $OUT/$NAME.crt (SAN: $san), valid $DAYS days"
