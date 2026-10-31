#!/usr/bin/env bash
# Apply the talos-cp-1 machine config, bootstrap etcd, and write a kubeconfig.
#
# Single-node layout: the control plane also runs all workloads.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-home}"
CP_IP="${CP_IP:-192.168.178.239}"
CONTEXT="${CONTEXT:-home}"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
export CLUSTER_NAME CP_IP CONTEXT KUBECONFIG

# Before the machine config is applied Talos runs in maintenance mode and uses
# DHCP, so it is reachable on a lease, not on CP_IP. Pass the lease here.
MAINTENANCE_IP="${MAINTENANCE_IP:-}"

if [[ -z "$MAINTENANCE_IP" ]]; then
  echo "set MAINTENANCE_IP to the Talos maintenance-mode DHCP lease" >&2
  echo "e.g. MAINTENANCE_IP=192.168.178.90 ./bootstrap/02-talos.sh" >&2
  exit 1
fi

export TALOSCONFIG="${TALOSCONFIG:-$ROOT/talos/generated/talosconfig}"
CONFIG="$ROOT/talos/generated/talos-cp-1.yaml"

for file in "$TALOSCONFIG" "$CONFIG"; do
  if [[ ! -f "$file" ]]; then
    echo "missing $file - run 'make secrets' first" >&2
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
deadline=$((SECONDS + 300))
while ((SECONDS < deadline)); do
  if output=$(talosctl bootstrap --nodes "$CP_IP" --talosconfig "$TALOSCONFIG" 2>&1); then
    echo "    ok: etcd bootstrap"
    break
  fi
  if [[ "$output" == *"already bootstrapped"* ]]; then
    echo "    ok: etcd already bootstrapped"
    break
  fi
  echo "    waiting for etcd: $output"
  sleep 5
done
if ((SECONDS >= deadline)); then
  echo "timed out waiting for etcd bootstrap" >&2
  exit 1
fi

echo "==> writing kubeconfig"
"$ROOT/bootstrap/04-kubeconfig.sh"

echo "==> waiting for the Kubernetes API"
wait_for "kubectl get nodes" 600 \
  kubectl --kubeconfig "$KUBECONFIG" --context "$CONTEXT" get nodes

kubectl --kubeconfig "$KUBECONFIG" --context "$CONTEXT" get nodes -o wide
