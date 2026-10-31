#!/usr/bin/env bash
# Write the cluster kubeconfig and select its local context.
#
# KUBECONFIG is used when set, otherwise ~/.kube/config.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-home}"
CP_IP="${CP_IP:-192.168.178.239}"
CONTEXT="${CONTEXT:-home}"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
TALOSCONFIG="${TALOSCONFIG:-$ROOT/talos/generated/talosconfig}"

if [[ "$KUBECONFIG" == *:* ]]; then
  echo "KUBECONFIG must be a single file path for this command" >&2
  exit 1
fi

mkdir -p "$(dirname "$KUBECONFIG")"

talosctl kubeconfig "$KUBECONFIG" \
  --merge=true --force \
  --nodes "$CP_IP" --talosconfig "$TALOSCONFIG"

contexts=$(kubectl --kubeconfig "$KUBECONFIG" config get-contexts -o name)

if ! grep -qx "$CONTEXT" <<<"$contexts"; then
  if grep -qx "admin@$CLUSTER_NAME" <<<"$contexts"; then
    kubectl --kubeconfig "$KUBECONFIG" \
      config rename-context "admin@$CLUSTER_NAME" "$CONTEXT"
  else
    echo "neither $CONTEXT nor admin@$CLUSTER_NAME is in $KUBECONFIG" >&2
    exit 1
  fi
fi

kubectl --kubeconfig "$KUBECONFIG" config use-context "$CONTEXT" >/dev/null

echo "==> kubeconfig written to $KUBECONFIG (context: $CONTEXT)"
