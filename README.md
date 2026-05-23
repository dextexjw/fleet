# NixOS Fleet Management

This is a starter template for a setup similar to how I manage my own home servers using NixOS + Colmena.

You can use this as a starting point for your own setup.

## Getting started

You need Nix installed on your machine first. If you don't have it, grab it from nixos.org or use the https://determinate.systems/ installer (has some QoL improvements).

If you use direnv (and you should), there's a `.envrc` file that will automatically load the development shell when you enter the directory. Otherwise run `nix develop` manually.

First thing you need is some servers running NixOS. Could be VMs, could be old laptops, whatever. Get them installed and grab their IP addresses.

Edit `hosts.nix` and put your servers in there. Change the IPs and usernames to match your setup. The tags are just for organizing things - you can deploy to all servers with a certain tag.

Each server gets its own directory under `hosts/`. Copy one of the existing ones and modify it. The `hardware-configuration.nix` file comes from running `nixos-generate-config` on the target machine (or just scp'ing it from /etc/nixos/hardware-configuration.nix from the target).

Once you have that sorted, run `nix develop` to get into the development shell, then `colmena apply` to deploy everything.

## How it works

The `modules/` directory contains reusable pieces for different services. Want to run Prometheus? Import the module and set `fleet.monitoring.prometheus.enable = true`. Same pattern for everything else.

All the servers import `hosts/common.nix` which sets up SSH keys, basic security, and monitoring. Individual servers add whatever services they need on top of that.

The reverse proxy on the gateway-vm server routes traffic to services running on different machines. Self-signed certificates handle TLS so you don't get browser warnings.

## Commands

Deploy everything: `colmena apply`

Deploy one server: `colmena apply --on servername`

Deploy servers with a tag: `colmena apply --on @web`

Run commands on servers: `colmena exec --on servername -- systemctl status nginx`

Build without deploying: `colmena build`

## media-vm runbook

### 7. Deploy future changes with Colmena

Enter the development shell first:

```sh
nix develop
```

Validate and build only `media-vm`:

```sh
scripts/check.sh
```

Deploy only `media-vm`:

```sh
scripts/deploy-media.sh
```

Equivalent Colmena commands:

```sh
colmena apply
colmena apply --on media-vm
colmena apply --on @media
colmena build --on media-vm
```

### 8. Check service status

```sh
colmena exec --on media-vm -- systemctl status jellyfin
colmena exec --on media-vm -- systemctl status radarr
colmena exec --on media-vm -- systemctl status sonarr
colmena exec --on media-vm -- systemctl status prowlarr
colmena exec --on media-vm -- systemctl status bazarr
colmena exec --on media-vm -- systemctl status qbittorrent
colmena exec --on media-vm -- systemctl status sabnzbd
colmena exec --on media-vm -- systemctl status jellyseerr
colmena exec --on media-vm -- systemctl status flaresolverr
colmena exec --on media-vm -- systemctl status prometheus-node-exporter
```

### 9. Access each web UI

- Jellyfin: `http://10.2.20.113:8096`
- Radarr: `http://10.2.20.113:7878`
- Sonarr: `http://10.2.20.113:8989`
- Prowlarr: `http://10.2.20.113:9696`
- Bazarr: `http://10.2.20.113:6767`
- qBittorrent: `http://10.2.20.113:8080`
- SABnzbd: `http://10.2.20.113:8085`
- Jellyseerr: `http://10.2.20.113:5055`

FlareSolverr listens on port `8191` for internal app integration and is not opened in the firewall.

### 10. Test the SMB mount

On `media-vm`:

```sh
mount /mnt/backups
ls -la /mnt/backups
```

You can also test the media share:

```sh
mount /mnt/media
ls -la /mnt/media
```

### 11. Run a manual backup

```sh
systemctl start appsdata-backup.service
```

### 12. Inspect backups

```sh
systemctl status appsdata-backup.timer
journalctl -u appsdata-backup.service
RESTIC_REPOSITORY=/mnt/backups/restic/appdata/media-stack-vm \
  RESTIC_PASSWORD_FILE=/run/secrets/restic-password \
  restic snapshots
```

### 13. Restore /srv/appsdata

1. Stop the media services:

```sh
systemctl stop jellyfin radarr sonarr prowlarr bazarr qbittorrent sabnzbd jellyseerr flaresolverr
```

2. Mount the backup share:

```sh
mount /mnt/backups
```

3. Restore the latest snapshot:

```sh
RESTIC_REPOSITORY=/mnt/backups/restic/appdata/media-stack-vm \
  RESTIC_PASSWORD_FILE=/run/secrets/restic-password \
  restic restore latest --target /
```

4. Reapply ownership from the NixOS config:

```sh
systemd-tmpfiles --create
systemctl start jellyfin radarr sonarr prowlarr bazarr qbittorrent sabnzbd jellyseerr flaresolverr
```

### 14. Roll back a NixOS deployment

From `media-vm`, choose the previous generation:

```sh
sudo nixos-rebuild switch --rollback
```

Or reboot and select an earlier generation in the bootloader menu. After rollback, check the affected services with `systemctl status`.

### 15. Safety notes around destructive disk installs

The VM disk is configured as `/dev/sda` in `hosts.nix`. Treat any install or partitioning command against that disk as destructive. Confirm the target VM ID, disk path, and console before running installer commands, and never run disk setup commands from this repository against a machine that has data you intend to keep.

### 16. App recovery backup boundary

`/srv/appsdata` is the single folder to back up for media-stack application recovery. It holds Jellyfin, Radarr, Sonarr, Prowlarr, Bazarr, qBittorrent, SABnzbd, Jellyseerr, FlareSolverr placeholder state, and monitoring backup state.

### 17. Media files are not in the appdata backup

Media files under `/mnt/media` are mounted from SMB and are not included in `appsdata-backup.service`. Back up the NAS media share separately if you want movie, TV, book, podcast, audiobook, comic, or PDF files protected.

## media-vm first run values

These values are already represented in `hosts.nix` and `hosts/media-vm/configuration.nix`:

- IP address: `10.2.20.113`
- Gateway: `10.2.20.1`
- DNS servers: `10.2.20.1`, `1.1.1.1`
- Admin username: `smoke`
- Admin SSH public key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATd/kn93HeAqaT5e8uW68n/JoWBesQkyruVNLsG3NDc khalid`
- Media SMB device: `//nas.home.arpa/media`
- Media mount: `/mnt/media`

Put the real values in `secrets/secrets.yaml`, then encrypt it with SOPS before deploying:

- `admin-password-hash`
- `smb-credentials`
- `restic-password`
- optional `qbittorrent-webui-password`

The committed `secrets/secrets.yaml` is an encrypted placeholder. Replace it with your real encrypted values and rekey it for the `media-vm` host before first deployment.

## Jellyfin kids access

Use one Jellyfin instance. After first Jellyfin setup, create a non-admin user named `kids`, grant only the Kids Movies and Kids TV Shows libraries, disable deletion, disable downloads unless wanted, and use parental controls or a `kids-approved` tag as a secondary control.

## Adding services

Look at the existing modules to see how they work. Most follow the same pattern: define some options, implement the service when enabled. Import the module in your server config and enable it.

The fleet namespace keeps things organized. Everything lives under `fleet.category.service` like `fleet.monitoring.grafana` or `fleet.dev.gitea`.

As mentioned in the video, AI can do wonders for this.

## Notes

Make sure your SSH key is in `hosts/common.nix` or you won't be able to deploy.

If services aren't accessible, check the firewall settings. Nothing is open by default.

As a quick hack, add the reverse proxy domains to your `/etc/hosts` file so they resolve properly. But better to set up proper DNS.

This setup assumes you're semi-comfortable with NixOS. If you're new to NixOS and flakes, check out the book: https://nixos-and-flakes.thiscute.world/

The monitoring stack will start collecting metrics immediately. Grafana runs on port 3000 of your gateway-vm server (or whatever you call your main one).


## Resources

- Check out [VimJoyer](https://www.youtube.com/@vimjoyer) for all of the Nix videos
- [NixOS + Flakes book](https://nixos-and-flakes.thiscute.world/)
- [Colmena](https://github.com/zhaofengli/colmena)
