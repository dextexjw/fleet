{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fleet.gateway.gluetun;
in
{
  # ============================================================================
  # MODULE OPTIONS
  # ============================================================================

  options.fleet.gateway.gluetun = {
    enable = mkEnableOption "Gluetun VPN gateway container";

    bindAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address used for exposed Gluetun proxy listeners.";
      example = "10.2.20.112";
    };

    httpProxy = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose Gluetun's unauthenticated HTTP proxy.";
      };

      port = mkOption {
        type = types.port;
        default = 8888;
        description = "Host and container port for Gluetun's HTTP proxy.";
      };
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/qdm12/gluetun@sha256:2f33c71e5e164fcd51a962cb950134df25155593edf0c3e1201f888d027049b4";
      description = "Pinned Gluetun OCI image reference.";
    };

    openvpnPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Runtime secret file containing the PIA OpenVPN password.";
    };

    openvpnUsernameFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Runtime secret file containing the PIA OpenVPN username.";
    };

    provider = mkOption {
      type = types.str;
      default = "private internet access";
      description = "Gluetun VPN service provider name.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "/srv/appsdata/gluetun";
      description = "Persistent Gluetun state directory.";
    };

    vpnPortForwarding = mkOption {
      type = types.bool;
      default = false;
      description = "Enable PIA VPN port forwarding.";
    };

    vpnType = mkOption {
      type = types.enum [ "openvpn" ];
      default = "openvpn";
      description = "Gluetun VPN protocol.";
    };
  };

  # ============================================================================
  # MODULE IMPLEMENTATION
  # ============================================================================

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.openvpnUsernameFile != null;
        message = "fleet.gateway.gluetun.openvpnUsernameFile must be set.";
      }
      {
        assertion = cfg.openvpnPasswordFile != null;
        message = "fleet.gateway.gluetun.openvpnPasswordFile must be set.";
      }
    ];

    boot.kernelModules = [ "tun" ];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0700 root root - -"
    ];

    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.gluetun = {
      image = cfg.image;
      pull = "missing";

      capabilities.NET_ADMIN = true;
      devices = [
        "/dev/net/tun:/dev/net/tun"
      ];

      environment = {
        FIREWALL_OUTBOUND_SUBNETS = "10.2.20.0/24";
        HTTPPROXY = if cfg.httpProxy.enable then "on" else "off";
        HTTPPROXY_LISTENING_ADDRESS = ":${toString cfg.httpProxy.port}";
        OPENVPN_PASSWORD_SECRETFILE = "/run/secrets/openvpn_password";
        OPENVPN_USER_SECRETFILE = "/run/secrets/openvpn_user";
        VPN_PORT_FORWARDING = if cfg.vpnPortForwarding then "on" else "off";
        VPN_SERVICE_PROVIDER = cfg.provider;
        VPN_TYPE = cfg.vpnType;
      } // optionalAttrs cfg.httpProxy.enable {
        FIREWALL_INPUT_PORTS = toString cfg.httpProxy.port;
      };

      ports = mkIf cfg.httpProxy.enable [
        "${cfg.bindAddress}:${toString cfg.httpProxy.port}:${toString cfg.httpProxy.port}/tcp"
      ];

      podman.sdnotify = "healthy";

      extraOptions = [
        "--health-cmd=/gluetun-entrypoint healthcheck"
        "--health-interval=5s"
        "--health-retries=1"
        "--health-start-period=10s"
        "--health-timeout=5s"
      ];

      volumes = [
        "${cfg.stateDir}:/gluetun"
        "${cfg.openvpnUsernameFile}:/run/secrets/openvpn_user:ro"
        "${cfg.openvpnPasswordFile}:/run/secrets/openvpn_password:ro"
      ];
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.httpProxy.enable [ cfg.httpProxy.port ];

    systemd.services.podman-gluetun = {
      after = [
        "network-online.target"
        "sops-install-secrets.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig.RestartSec = "30s";
    };
  };
}
