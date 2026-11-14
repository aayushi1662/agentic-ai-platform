#!/usr/bin/env bash
# Creates a local RSA key pair for signing and verifying development JWTs (RS256).
# The private key stays with the ingest service only. These files are git-ignored: never commit them.
set -euo pipefail
mkdir -p .dev-keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out .dev-keys/private.pem
openssl rsa -pubout -in .dev-keys/private.pem -out .dev-keys/public.pem
chmod 600 .dev-keys/private.pem
echo "created .dev-keys/private.pem and .dev-keys/public.pem"
