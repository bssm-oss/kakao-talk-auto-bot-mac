#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="katalk-ax Local Signing"
KEYCHAIN_PATH="$HOME/Library/Keychains/login.keychain-db"
PKCS12_PASSWORD="katalk-ax-local-signing"

EXISTING_IDENTITY=$(security find-certificate -Z -a -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" 2>/dev/null | awk '/SHA-1 hash:/ { print $3; exit }' || true)
if [[ -n "$EXISTING_IDENTITY" ]]; then
  printf '%s\n' "$EXISTING_IDENTITY"
  exit 0
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/openssl.cnf" <<'EOF'
[ req ]
default_bits = 2048
distinguished_name = dn
x509_extensions = ext
prompt = no

[ dn ]
CN = katalk-ax Local Signing

[ ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl genrsa -out "$WORK_DIR/key.pem" 2048 >/dev/null 2>&1
openssl req -new -x509 -days 3650 -key "$WORK_DIR/key.pem" -out "$WORK_DIR/cert.pem" -config "$WORK_DIR/openssl.cnf" >/dev/null 2>&1
openssl pkcs12 -legacy -export -inkey "$WORK_DIR/key.pem" -in "$WORK_DIR/cert.pem" -out "$WORK_DIR/cert.p12" -passout pass:"$PKCS12_PASSWORD" >/dev/null 2>&1

security import "$WORK_DIR/cert.p12" -k "$KEYCHAIN_PATH" -P "$PKCS12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null

NEW_IDENTITY=$(security find-certificate -Z -a -c "$IDENTITY_NAME" "$KEYCHAIN_PATH" 2>/dev/null | awk '/SHA-1 hash:/ { print $3; exit }' || true)
if [[ -z "$NEW_IDENTITY" ]]; then
  echo "Failed to create local signing identity" >&2
  exit 1
fi

printf '%s\n' "$NEW_IDENTITY"
