#!/usr/bin/env bash
# Join the optional worker VMs to the existing cluster.
#
# Only needed when worker VMs are added later. Generate their configs first:
#   WORKERS="talos-worker-1 talos-worker-2" make secrets
#
# Each worker boots the Talos ISO into maintenance mode and gets a DHCP lease.
# Pass those leases; the static addresses come from the machine config.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${CONTEXT:-home}"

export TALOSCONFIG="${TALOSCONFIG:-$ROOT/talos/generated/talosconfig}"

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

join_worker() {
  local name="$1" ip="$2" maintenance_ip="$3"
  local config="$ROOT/talos/generated/$name.yaml"

  if [[ ! -f "$config" ]]; then
    echo "missing $config - run 'WORKERS=\"$name\" make secrets' first" >&2
    exit 1
  fi

  echo "==> $name: waiting for $maintenance_ip in maintenance mode"
  wait_for "$name maintenance API" 300 \
    talosctl version --nodes "$maintenance_ip" --insecure --talosconfig "$TALOSCONFIG"

  echo "==> $name: applying worker config (installs to disk, then reboots)"
  talosctl apply-config --insecure --nodes "$maintenance_ip" \
    --file "$config" --talosconfig "$TALOSCONFIG"

  echo "==> $name: waiting for $ip"
  wait_for "$name Talos API" 600 \
    talosctl version --nodes "$ip" --talosconfig "$TALOSCONFIG"

  echo "==> $name: waiting for Ready"
  wait_for "$name Ready" 600 \
    kubectl --context "$CONTEXT" wait --for=condition=Ready "node/$name" --timeout=10s
}

: "${WORKER1_MAINTENANCE_IP:?set WORKER1_MAINTENANCE_IP to the DHCP lease of talos-worker-1}"
: "${WORKER2_MAINTENANCE_IP:?set WORKER2_MAINTENANCE_IP to the DHCP lease of talos-worker-2}"

join_worker talos-worker-1 192.168.178.241 "$WORKER1_MAINTENANCE_IP"
join_worker talos-worker-2 192.168.178.242 "$WORKER2_MAINTENANCE_IP"

echo
kubectl --context "$CONTEXT" get nodes -o wide
