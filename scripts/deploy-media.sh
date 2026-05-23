#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="media-vm"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v colmena >/dev/null 2>&1 || die "colmena is missing; run nix develop first"

cd "$ROOT"

if [[ ! -f secrets/secrets.yaml ]]; then
  die "missing secrets/secrets.yaml"
fi

colmena apply --on "$HOST" switch
