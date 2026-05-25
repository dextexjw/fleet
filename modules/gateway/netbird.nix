{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fleet.gateway.netbird;
in
{
  # ============================================================================
  # MODULE OPTIONS
  # ============================================================================

  options.fleet.gateway.netbird = {
    enable = mkEnableOption "NetBird WireGuard mesh client";

    interface = mkOption {
      type = types.str;
      default = "wt0";
      description = "NetBird WireGuard interface name.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the NetBird WireGuard UDP port.";
    };

    port = mkOption {
      type = types.port;
      default = 51820;
      description = "NetBird WireGuard UDP port.";
    };

    useRoutingFeatures = mkOption {
      type = types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = "Enable NetBird routing features for routes or exit nodes.";
    };
  };

  # ============================================================================
  # MODULE IMPLEMENTATION
  # ============================================================================

  config = mkIf cfg.enable {
    services.netbird = {
      enable = true;
      ui.enable = false;
      useRoutingFeatures = cfg.useRoutingFeatures;

      clients.default = {
        interface = cfg.interface;
        openFirewall = cfg.openFirewall;
        port = cfg.port;
      };
    };
  };
}
