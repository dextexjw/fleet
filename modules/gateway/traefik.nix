{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fleet.gateway.traefik;

  dashboardHost =
    if cfg.dashboard.domain == null then
      "traefik.${cfg.domain}"
    else
      cfg.dashboard.domain;

  routerEntryPoints =
    if cfg.enableTLS then
      [ "websecure" ]
    else
      [ "web" ];

  mkName =
    name:
    replaceStrings
      [
        "."
        "*"
      ]
      [
        "-"
        "wildcard"
      ]
      name;

  mkRouter =
    name: route:
    nameValuePair (mkName name) (
      {
        entryPoints = routerEntryPoints;
        rule = "Host(`${route.host}`)";
        service = mkName name;
      }
      // optionalAttrs cfg.enableTLS { tls = { }; }
    );

  mkService =
    name: route:
    nameValuePair (mkName name) {
      loadBalancer.servers = [
        {
          url = route.url;
        }
      ];
    };

  dashboardRouters = optionalAttrs cfg.dashboard.enable {
    dashboard = (
      {
        entryPoints = routerEntryPoints;
        rule = "Host(`${dashboardHost}`)";
        service = "api@internal";
      }
      // optionalAttrs cfg.enableTLS { tls = { }; }
    );
  };
in
{
  # ============================================================================
  # MODULE OPTIONS
  # ============================================================================

  options.fleet.gateway.traefik = {
    enable = mkEnableOption "Traefik gateway ingress";

    dashboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose the Traefik dashboard through the file provider.";
      };

      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Dashboard hostname. Defaults to traefik.<domain>.";
        example = "traefik.home.arpa";
      };
    };

    domain = mkOption {
      type = types.str;
      default = "home.arpa";
      description = "Internal homelab domain used for generated defaults.";
    };

    enableTLS = mkOption {
      type = types.bool;
      default = false;
      description = "Attach a TLS router on the websecure entrypoint.";
    };

    httpPort = mkOption {
      type = types.port;
      default = 80;
      description = "HTTP entrypoint port.";
    };

    httpsPort = mkOption {
      type = types.port;
      default = 443;
      description = "HTTPS entrypoint port.";
    };

    logLevel = mkOption {
      type = types.enum [
        "DEBUG"
        "INFO"
        "WARN"
        "ERROR"
      ];
      default = "INFO";
      description = "Traefik log level.";
    };

    routes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable route purpose.";
          };

          host = mkOption {
            type = types.str;
            description = "Hostname matched by Traefik.";
            example = "homepage.home.arpa";
          };

          url = mkOption {
            type = types.str;
            description = "Backend URL Traefik should proxy to.";
            example = "http://10.2.20.113:8096";
          };
        };
      });
      default = { };
      description = "Named Traefik HTTP routes.";
    };
  };

  # ============================================================================
  # MODULE IMPLEMENTATION
  # ============================================================================

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;

      dynamicConfigOptions.http = {
        routers = dashboardRouters // mapAttrs' mkRouter cfg.routes;
        services = mapAttrs' mkService cfg.routes;
      };

      staticConfigOptions = {
        api.dashboard = cfg.dashboard.enable;

        entryPoints = {
          web.address = ":${toString cfg.httpPort}";
          websecure.address = ":${toString cfg.httpsPort}";
        };

        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        log.level = cfg.logLevel;
      };
    };

    networking.firewall.allowedTCPPorts =
      [ cfg.httpPort ] ++ optional cfg.enableTLS cfg.httpsPort;
  };
}
