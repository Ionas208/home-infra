# Network

> Status: target design for Phase 1-2. Addresses are placeholders.

## Address plan

All addresses are placeholders.

| Name | Address | Notes |
|---|---|---|
| LAN | `192.0.2.0/24` | replace with the real LAN |
| Gateway | `192.0.2.1` | FRITZ!Box |
| Proxmox host | `192.0.2.5` | static, outside DHCP |
| Talos CP | `192.0.2.10` | Kubernetes API endpoint |
| Talos worker 1 | `192.0.2.11` | |
| Talos worker 2 | `192.0.2.12` | |
| Traefik VIP | `192.0.2.50` | MetalLB |
| DNS VIP | `192.0.2.53` | MetalLB |
| QNAP | `192.0.2.254` | static |
| MetalLB pool | `192.0.2.50-192.0.2.59` | resize to fit |

Keep VIPs outside the FRITZ!Box DHCP pool.

## Proxmox

- `vmbr0` bridged to the LAN.
- Static management IP.
- No inbound port forwarding.
- Proxmox firewall enabled after the cluster is stable.
- Proxmox host DNS: FRITZ!Box or public resolvers, not the in-cluster DNS.

## Talos

- Static IPs configured in `talos/patches/cp-1.yaml`, `worker-1.yaml`, `worker-2.yaml`.
- DNS: public resolvers or FRITZ!Box, not `lan-dns`.
- One control plane; no API VIP.
- `cluster.allowSchedulingOnControlPlanes: true`.
- `siderolabs/nfs-utils` extension for QNAP NFS.

## DNS

- `lan-dns` CoreDNS runs in Kubernetes and owns `home.jonasseidl.com`.
- Wildcard `*.home.jonasseidl.com` -> Traefik VIP.
- Explicit records for Proxmox, QNAP, Talos.
- DHCP stays on the FRITZ!Box.
- Primary DNS advertised to LAN clients: `<DNS_VIP>`.
- Secondary DNS: FRITZ!Box or public resolver.
- Public DNS: explicit Cloudflare records only; no public wildcard.
- Public names go through Cloudflare Tunnel.

## Ingress

- Traefik `web` (80): Cloudflare Tunnel origin and public routes.
- Traefik `websecure` (443): internal routes with the wildcard certificate.
- No global HTTP-to-HTTPS redirect; it would break the tunnel origin.
- Admin UIs are internal only and/or behind Tailscale.

## QNAP

- Address `<QNAP_IP>` (`.254`).
- 1x 2.5GbE and 1x 1GbE. Use 2.5GbE if the switch and Proxmox NIC support it;
  otherwise 1GbE is fine for media and backups.
- NFSv4.1 exports to explicit node/Proxmox IPs only.
- No public exposure, no UPnP, no port forwarding.
- Admin only from LAN or the emergency WireGuard VPN.

## Tailscale

- Tailscale operator runs in Kubernetes.
- No Tailscale client on Proxmox by default.
- Optional `Connector` CRD can advertise the LAN subnet while the cluster is up.
- Emergency remote access when the cluster is down: FRITZ!Box WireGuard.

## Firewall

Minimum rules:

- Allow LAN -> Proxmox `8006` (admin UI), SSH from admin hosts.
- Allow LAN -> Talos nodes `6443` (Kubernetes API) and `50000` (Talos API) only if
  required; prefer Tailscale.
- Allow LAN -> QNAP `443`/`445` as needed; NFS only from the cluster/Proxmox.
- No inbound from the internet.
- Outbound: Cloudflare Tunnel, Tailscale, GHCR, BSM, DNS, NTP.
