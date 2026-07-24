{ config, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = [
      "audiomuse"
    ];
    ensureUsers = [
      {
        name = "audiomuse";
        ensureDBOwnership = true;
      }
      {
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      host  audiomuse  audiomuse  172.16.0.0/12  scram-sha-256
    '';
  };

  services.redis.servers.audiomuse = {
    enable = true;
    port = 6380;
    bind = "0.0.0.0";
    requirePassFile = "/home/egecelikci/.config/redis/audiomuse-password";
  };
}
