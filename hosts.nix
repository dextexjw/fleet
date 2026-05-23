# ============================================================================
# FLEET HOST DEFINITIONS
# Single source of truth for all host information
# ============================================================================

{
  gateway-vm = {
    ip = "10.2.20.112";
    user = "smoke";
    tags = [
      "control-plane"
      "monitoring"
    ];
  };

  media-vm = {
    arch = "x86_64-linux";
    domain = "home.arpa";
    fqdn = "media.home.arpa";
    gateway = "10.2.20.1";
    ip = "10.2.20.113";
    nameservers = [
      "10.2.20.1"
      "1.1.1.1"
    ];
    user = "smoke";
    tags = [
      "media"
    ];
    timezone = "America/New_York";
    vm = {
      cores = 4;
      disk = "/dev/sda";
      id = "113";
      name = "media-vm";
      ramGB = 12;
    };
  };
}
