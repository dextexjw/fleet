{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fleet.gateway.tailscale;
in
{
  # ============================================================================
  # MODULE OPTIONS
  # ============================================================================

  options.fleet.gateway.tailscale = {
    enable = mkEnableOption "Tailscale secure overlay client";

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Runtime path containing a Tailscale auth key.";
      example = "/run/secrets/tailscale-auth-key";
    };

    extraSetFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags passed to tailscale set.";
    };

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags passed to tailscale up when authKeyFile is set.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Tailscale UDP port.";
    };

    port = mkOption {
      type = types.port;
      default = 41641;
      description = "Tailscale UDP port.";
    };

    useRoutingFeatures = mkOption {
      type = types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = "Enable Tailscale routing features for subnet routes or exit nodes.";
    };
  };

  # ============================================================================
  # MODULE IMPLEMENTATION
  # ============================================================================

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = cfg.authKeyFile;
      extraSetFlags = cfg.extraSetFlags;
      extraUpFlags = cfg.extraUpFlags;
      openFirewall = cfg.openFirewall;
      port = cfg.port;
      useRoutingFeatures = cfg.useRoutingFeatures;
    };
  };
}
