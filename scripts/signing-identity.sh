#!/usr/bin/env bash
# Creates a self-signed code-signing identity so every build has the same identity
# and macOS keeps the Accessibility grant across rebuilds. Run once.
set -euo pipefail
NAME="Control Island Dev"
if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "Identity '$NAME' already exists."
  exit 0
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/ext.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/ext.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/identity.p12" -passout pass:island -legacy 2>/dev/null \
  || openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/identity.p12" -passout pass:island
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P island -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true
echo "Created identity '$NAME'."
security find-identity -v -p codesigning | grep "$NAME"
