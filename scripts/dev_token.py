#!/usr/bin/env python3
"""Mint a DEVELOPMENT-ONLY JWT so you can call services before the real login exists (Week 1 to 5).

Example:
  python scripts/dev_token.py --tenant 11111111-1111-4111-8111-111111111111 --role approver
Requires: pip install "pyjwt[crypto]" and `make dev-keys` first.
Never use this outside your laptop. In real use the ingest (Django) service issues tokens.
"""
import argparse
import sys
import time
from pathlib import Path

import jwt

parser = argparse.ArgumentParser()
parser.add_argument("--tenant", required=True, help="tenant UUID")
parser.add_argument(
    "--role", action="append", default=[], choices=["viewer", "reviewer", "approver", "admin"]
)
parser.add_argument("--sub", default="dev-user@example.com")
parser.add_argument("--minutes", type=int, default=60)
parser.add_argument("--key", default=".dev-keys/private.pem")
args = parser.parse_args()

key_path = Path(args.key)
if not key_path.exists():
    sys.exit("private key not found: run `make dev-keys` first")

claims = {
    "sub": args.sub,
    "tenant_id": args.tenant,
    "roles": args.role or ["viewer"],
    "iss": "ingest",
    "exp": int(time.time()) + args.minutes * 60,
}
print(jwt.encode(claims, key_path.read_text(), algorithm="RS256"))
