{ config, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    settings.listen_addresses = "*";
    ensureDatabases = [
      "audiomuse"
      "mas"
    ];
    ensureUsers = [
      {
        name = "audiomuse";
        ensureDBOwnership = true;
      }
      {
        name = "mas";
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      host  audiomuse  audiomuse  172.16.0.0/12  scram-sha-256
      host  mas        mas        172.16.0.0/12  trust
      host  mas        mas        127.0.0.1/32   trust
    '';
  };

  services.redis.servers.audiomuse = {
    enable = true;
    port = 6380;
    bind = "0.0.0.0";
    requirePassFile = "/home/egecelikci/.config/redis/audiomuse-password";
  };
}
