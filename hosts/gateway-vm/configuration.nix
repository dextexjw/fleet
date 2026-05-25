{ lib, ... }:

let
  hosts = import ../../hosts.nix;
  domain = hosts.gateway-vm.domain;
in

{
  # ============================================================================
  # IMPORTS
  # ============================================================================

  imports = [
    ../common.nix
    ./hardware-configuration.nix
    ../../modules/gateway/netbird.nix
    ../../modules/gateway/netbootxyz.nix
    ../../modules/gateway/tailscale.nix
    ../../modules/gateway/technitium.nix
    ../../modules/gateway/traefik.nix
  ];

  # ============================================================================
  # HOST IDENTIFICATION
  # ============================================================================

  networking.hostName = "gateway-vm";
  users.motd = "gateway-vm: Traefik ingress, Technitium DNS, netboot.xyz, NetBird, and Tailscale";

  # ============================================================================
  # SERVICES
  # ============================================================================

  fleet.gateway.netbird = {
    enable = true;
  };

  fleet.gateway.netbootxyz = {
    enable = true;
    bindAddress = hosts.gateway-vm.ip;
  };

  fleet.gateway.tailscale = {
    enable = true;
  };

  fleet.gateway.technitium = {
    enable = true;
  };

  fleet.gateway.traefik = {
    dashboard.domain = "traefik.${domain}";
    domain = domain;
    enable = true;
    routes = {
      audiobookshelf = {
        description = "Audiobookshelf media library";
        host = "audiobookshelf.${domain}";
        url = "http://${hosts.media-vm.ip}:8000";
      };
      bazarr = {
        description = "Bazarr subtitle management";
        host = "bazarr.${domain}";
        url = "http://${hosts.media-vm.ip}:6767";
      };
      jellyfin = {
        description = "Jellyfin media server";
        host = "jellyfin.${domain}";
        url = "http://${hosts.media-vm.ip}:8096";
      };
      jellyseerr = {
        description = "Jellyseerr requests";
        host = "jellyseerr.${domain}";
        url = "http://${hosts.media-vm.ip}:5055";
      };
      kavita = {
        description = "Kavita library";
        host = "kavita.${domain}";
        url = "http://${hosts.media-vm.ip}:5000";
      };
      prowlarr = {
        description = "Prowlarr indexer management";
        host = "prowlarr.${domain}";
        url = "http://${hosts.media-vm.ip}:9696";
      };
      qbittorrent = {
        description = "qBittorrent downloads";
        host = "qbittorrent.${domain}";
        url = "http://${hosts.media-vm.ip}:8080";
      };
      radarr = {
        description = "Radarr movie management";
        host = "radarr.${domain}";
        url = "http://${hosts.media-vm.ip}:7878";
      };
      sabnzbd = {
        description = "SABnzbd downloads";
        host = "sabnzbd.${domain}";
        url = "http://${hosts.media-vm.ip}:8085";
      };
      sonarr = {
        description = "Sonarr TV management";
        host = "sonarr.${domain}";
        url = "http://${hosts.media-vm.ip}:8989";
      };
      technitium = {
        description = "Technitium DNS administration and DoH endpoint";
        host = "technitium.${domain}";
        url = "http://127.0.0.1:5380";
      };
    };
  };

  # common.nix enables node-exporter by default; gateway-vm intentionally does
  # not run monitoring services.
  fleet.monitoring.nodeExporter.enable = lib.mkForce false;

  # ============================================================================
  # NETWORKING & FIREWALL
  # ============================================================================

  networking.firewall.allowedTCPPorts = [ ];

  # ============================================================================
  # BOOTLOADER
  # ============================================================================

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # ============================================================================
  # SYSTEM
  # ============================================================================

  environment.etc."fleet/gateway-vm.md".text = ''
    gateway-vm service model
    ========================

    gateway-vm is scoped to Traefik, Technitium, netboot.xyz, NetBird, and
    Tailscale. Prometheus, Grafana, Jenkins, nginx reverse proxy, and node
    exporter are intentionally not enabled on this host.

    Homelab domain:
      *.${domain}

    Declared services:
      Traefik: traefik.service, ports 80 and optional 443
      Technitium: technitium-dns-server.service, state /var/lib/technitium-dns-server
      netboot.xyz: atftpd.service, TFTP root /srv/netbootxyz, boot file netboot.xyz.efi
      NetBird: netbird.service, state /var/lib/netbird
      Tailscale: tailscaled.service, state /var/lib/tailscale

    Internal routes:
      http://traefik.${domain}
      http://technitium.${domain}
      http://jellyfin.${domain}
      http://audiobookshelf.${domain}
      http://kavita.${domain}
      http://sonarr.${domain}
      http://radarr.${domain}
      http://prowlarr.${domain}
      http://bazarr.${domain}
      http://qbittorrent.${domain}
      http://sabnzbd.${domain}
      http://jellyseerr.${domain}

    Network boot:
      Configure the LAN DHCP server to point option 66 at ${hosts.gateway-vm.ip}
      and option 67 at netboot.xyz.efi. gateway-vm only serves TFTP and does not
      take over DHCP for the subnet.

    Guarded deploy workflow:
      nix develop
      nix flake check
      colmena build --on gateway-vm
      colmena apply --on gateway-vm dry-activate
      colmena apply --on gateway-vm switch

    Post-deploy validation:
      systemctl is-active traefik.service
      systemctl is-active technitium-dns-server.service
      systemctl is-active atftpd.service
      systemctl is-active netbird.service
      systemctl is-active tailscaled.service
      ss -lntu

    Recovery notes:
      Technitium holds DNS zones and resolver configuration under
      /var/lib/technitium-dns-server. Export DNS settings and zones from
      Technitium before upgrades that may affect DNS state, keep exports
      encrypted off-host, and restore them through the Technitium admin UI
      after a rebuild.

      NetBird and Tailscale enrollment state lives under /var/lib/netbird and
      /var/lib/tailscale. Re-enroll the host after rebuild if runtime state is
      unavailable. Keep auth keys in encrypted secrets only; do not write them
      into Nix files or recovery notes.
  '';

  system.stateVersion = "25.11";
}
