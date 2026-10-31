#!/usr/bin/env bash
# Publish host facts that node-exporter cannot derive from /proc or /sys.
#
# Writes an atomically replaced .prom file into the textfile collector
# directory, which prometheus-node-exporter serves on :9100/metrics.
set -euo pipefail

DIR=/var/lib/prometheus/node-exporter
OUT="$DIR/host.prom"
TMP="$OUT.tmp"

install -d -m 0755 "$DIR"

reboot_required=0
[[ -e /var/run/reboot-required ]] && reboot_required=1

# "Inst <pkg> ..." lines are the packages the next upgrade would install.
upgradable=$(apt-get --just-print upgrade 2>/dev/null | grep -c '^Inst' || true)
[[ -z "$upgradable" ]] && upgradable=0

# Thin-pool exhaustion breaks vzdump snapshots and new VM disks, and it is
# invisible to node_filesystem_* because local-lvm is not a mounted filesystem.
thin_used=$(lvs --noheadings --units g -o data_percent pve/data 2>/dev/null | tr -d ' ' || true)
[[ -z "$thin_used" ]] && thin_used=0

{
  echo '# HELP node_reboot_required 1 when /var/run/reboot-required exists.'
  echo '# TYPE node_reboot_required gauge'
  echo "node_reboot_required $reboot_required"
  echo '# HELP pve_apt_upgradable Packages with an available upgrade.'
  echo '# TYPE pve_apt_upgradable gauge'
  echo "pve_apt_upgradable $upgradable"
  echo '# HELP pve_thinpool_used_percent Used percentage of the pve/data thin pool.'
  echo '# TYPE pve_thinpool_used_percent gauge'
  echo "pve_thinpool_used_percent $thin_used"
} >"$TMP"

mv "$TMP" "$OUT"
chmod 0644 "$OUT"
