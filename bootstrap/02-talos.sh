#!/usr/bin/env bash
# Apply the talos-cp-1 machine config, bootstrap etcd, and write a kubeconfig.
#
# Single-node layout: the control plane also runs all workloads.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-home}"
CP_IP="${CP_IP:-192.168.178.239}"
# Before the machine config is applied Talos runs in maintenance mode and uses
# DHCP, so it is reachable on a lease, not on CP_IP. Pass the lease here.
MAINTENANCE_IP="${MAINTENANCE_IP:-}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/config}"
CONTEXT="${CONTEXT:-home}"

if [[ -z "$MAINTENANCE_IP" ]]; then
  echo "set MAINTENANCE_IP to the Talos maintenance-mode DHCP lease" >&2
  echo "e.g. MAINTENANCE_IP=192.168.178.90 ./bootstrap/02-talos.sh" >&2
  exit 1
fi

export TALOSCONFIG="${TALOSCONFIG:-$ROOT/talos/generated/talosconfig}"
CONFIG="$ROOT/talos/generated/talos-cp-1.yaml"

for file in "$TALOSCONFIG" "$CONFIG"; do
  if [[ ! -f "$file" ]]; then
    echo "missing $file - run talos/generate.sh first" >&2
    exit 1
  fi
done

wait_for() {
  local description="$1" seconds="$2"
  shift 2
  local deadline=$((SECONDS + seconds))

  while ((SECONDS < deadline)); do
    if "$@" >/dev/null 2>&1; then
      echo "    ok: $description"
      return 0
    fi
    sleep 5
  done

  echo "timed out waiting for $description" >&2
  return 1
}

echo "==> waiting for $MAINTENANCE_IP to answer in maintenance mode"
wait_for "maintenance API on $MAINTENANCE_IP" 300 \
  talosctl version --nodes "$MAINTENANCE_IP" --insecure --talosconfig "$TALOSCONFIG"

echo "==> applying control-plane config (installs Talos to disk, then reboots)"
talosctl apply-config --insecure --nodes "$MAINTENANCE_IP" \
  --file "$CONFIG" --talosconfig "$TALOSCONFIG"

echo "==> waiting for the configured node"
wait_for "configured Talos API on $CP_IP" 600 \
  talosctl version --nodes "$CP_IP" --talosconfig "$TALOSCONFIG"

echo "==> bootstrapping etcd"
talosctl bootstrap --nodes "$CP_IP" --talosconfig "$TALOSCONFIG"

echo "==> writing kubeconfig to $KUBECONFIG_PATH (context: $CONTEXT)"
mkdir -p "$(dirname "$KUBECONFIG_PATH")"
talosctl kubeconfig "$KUBECONFIG_PATH" \
  --merge=true --force \
  --nodes "$CP_IP" --talosconfig "$TALOSCONFIG"

# talosctl ignores --force-context-name here and writes admin@<cluster>.
if ! kubectl config get-contexts -o name --kubeconfig "$KUBECONFIG_PATH" | grep -qx "$CONTEXT"; then
  kubectl config rename-context "admin@$CLUSTER_NAME" "$CONTEXT" --kubeconfig "$KUBECONFIG_PATH"
fi
kubectl config use-context "$CONTEXT" --kubeconfig "$KUBECONFIG_PATH" >/dev/null

echo "==> waiting for the Kubernetes API"
wait_for "kubectl get nodes" 600 \
  kubectl --context "$CONTEXT" get nodes

kubectl --context "$CONTEXT" get nodes -o wide
