#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="media-vm"
HOST_IP="10.2.20.113"
SECRETS="$ROOT/secrets/secrets.yaml"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v colmena >/dev/null 2>&1 || die "colmena is missing; run nix develop first"
command -v sops >/dev/null 2>&1 || die "sops is missing; run nix develop first"
command -v ssh >/dev/null 2>&1 || die "ssh is missing"

cd "$ROOT"

if [[ ! -f "$SECRETS" ]]; then
  die "missing $SECRETS"
fi

if ! sops --decrypt "$SECRETS" >/dev/null; then
  die "unable to decrypt $SECRETS locally; rekey it for your local/admin key"
fi

if ! target_pubkey="$(
  ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "smoke@$HOST_IP" \
    'sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key' \
    2>/dev/null \
    | awk '{print $1 " " $2}'
)"; then
  die "unable to read $HOST SOPS SSH host public key from $HOST_IP"
fi

if [[ -z "$target_pubkey" ]]; then
  die "unable to read $HOST SOPS SSH host public key from $HOST_IP"
fi

if ! grep -Fq "$target_pubkey" "$SECRETS"; then
  die "$HOST cannot decrypt $SECRETS; add '$target_pubkey media-vm' to .sops.yaml, then run: sops updatekeys secrets/secrets.yaml"
fi

colmena apply --on "$HOST" switch
