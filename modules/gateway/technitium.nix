{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fleet.gateway.technitium;
in
{
  # ============================================================================
  # MODULE OPTIONS
  # ============================================================================

  options.fleet.gateway.technitium = {
    enable = mkEnableOption "Technitium DNS Server";

    dnsOverTlsPort = mkOption {
      type = types.port;
      default = 853;
      description = "DNS-over-TLS port to allow through the firewall.";
    };

    dnsPort = mkOption {
      type = types.port;
      default = 53;
      description = "Recursive DNS port.";
    };

    httpsPort = mkOption {
      type = types.port;
      default = 53443;
      description = "Technitium HTTPS and DNS-over-HTTPS port.";
    };

    webPort = mkOption {
      type = types.port;
      default = 5380;
      description = "Technitium HTTP administration port.";
    };
  };

  # ============================================================================
  # MODULE IMPLEMENTATION
  # ============================================================================

  config = mkIf cfg.enable {
    services.technitium-dns-server = {
      enable = true;
      openFirewall = true;
      firewallTCPPorts = unique [
        cfg.dnsPort
        cfg.dnsOverTlsPort
        cfg.httpsPort
        cfg.webPort
      ];
      firewallUDPPorts = [ cfg.dnsPort ];
    };
  };
}
