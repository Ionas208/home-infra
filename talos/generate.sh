#!/usr/bin/env bash
# Generate the Talos secrets bundle and the talos-cp-1 machine config.
#
# Phase 1A: control plane only. Worker patches are added in Phase 1B.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHES="$ROOT/talos/patches"
SECRETS_DIR="$ROOT/talos/secrets"
SECRETS="$SECRETS_DIR/secrets.yaml"
GENERATED="$ROOT/talos/generated"

CLUSTER_NAME="${CLUSTER_NAME:-home}"
CP_IP="${CP_IP:-192.168.178.240}"

mkdir -p "$SECRETS_DIR" "$GENERATED"
chmod 700 "$SECRETS_DIR"

if [[ -f "$SECRETS" ]]; then
  echo "Reusing secrets bundle: $SECRETS"
else
  echo "Generating secrets bundle: $SECRETS"
  talosctl gen secrets -o "$SECRETS"
  chmod 600 "$SECRETS"
fi

echo "Generating talos-cp-1 machine config for https://${CP_IP}:6443"

talosctl gen config "$CLUSTER_NAME" "https://${CP_IP}:6443" \
  --with-secrets "$SECRETS" \
  --config-patch "@$PATCHES/common.yaml" \
  --config-patch-control-plane "@$PATCHES/controlplane.yaml" \
  --output-types controlplane,talosconfig \
  --output "$GENERATED" \
  --with-docs=false \
  --with-examples=false \
  --force

mv "$GENERATED/controlplane.yaml" "$GENERATED/talos-cp-1.yaml"
chmod 600 "$GENERATED/talosconfig"

# gen config leaves the context without endpoints/nodes, which makes every
# later talosctl call fail with "failed to determine endpoints".
talosctl --talosconfig "$GENERATED/talosconfig" config endpoint "$CP_IP"
talosctl --talosconfig "$GENERATED/talosconfig" config node "$CP_IP"

echo
echo "Generated:"
echo "  $SECRETS"
echo "  $GENERATED/talos-cp-1.yaml"
echo "  $GENERATED/talosconfig"
echo
echo "Back up $SECRETS to Bitwarden Secrets Manager and the offline recovery kit."
