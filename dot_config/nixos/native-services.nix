{ config, lib, pkgs, ... }:

let
  domain    = "balcova.online";
  mediaRoot = "/mnt/media";
  homeDir   = "/home/egecelikci";
  mediaUser = "media";
  mediaGroup = "media";
in
{
  users.groups.${mediaGroup} = {};
  users.users.${mediaUser} = {
    isSystemUser = true;
    group = mediaGroup;
    extraGroups = [ "render" "video" ];
  };

  services.jellyfin = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    openFirewall = false;
  };

  services.navidrome = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "${mediaRoot}/Music/Library";
      LogLevel = "info";
      EnableSharing = true;
      Agents = "audiomuseai,listenbrainz,apple-music,deezer";
      Scanner.ScanSchedule = "@every 1h";
    };
  };
  systemd.services.navidrome.serviceConfig.EnvironmentFile = "${homeDir}/.config/navidrome/navidrome.env";

  services.prowlarr.enable = true;
  services.radarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.sonarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.bazarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.lidarr  = { enable = true; user = mediaUser; group = mediaGroup; };

  services.qbittorrent = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    webuiPort = 8080;
    torrentingPort = 50413;
    openFirewall = false;
  };

  services.flaresolverr.enable = true;

  services.seerr = {
    enable = true;
    port = 5055;
    openFirewall = false;
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = [ "audiomuse" ];
    ensureUsers = [{
      name = "audiomuse";
      ensureDBOwnership = true;
    }];
    authentication = ''
      host  audiomuse  audiomuse  172.16.0.0/12  scram-sha-256
    '';
  };

  services.redis.servers.audiomuse = {
    enable = true;
    port = 6380;
    bind = "0.0.0.0";
    settings.requirepass = "...";
  };

  networking.firewall.interfaces.docker0.allowedTCPPorts = [ 5432 6380 ];

services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-hEHgAG0F0ozHRAPuxEqLyTATBrE+pajeXDiSNwniorg=";
    };

    globalConfig = ''
      email ege@celikci.me
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      servers {
          protocols h1 h2
      }
    '';

    extraConfig = ''
      balcova.online {
          redir https://id.balcova.online{uri}
      }

      (tinyauth_forwarder) {
        forward_auth 127.0.0.1:3000 {
          uri /api/auth/caddy
          copy_headers Remote-User Remote-Name Remote-Email Remote-Groups
          header_up X-Forwarded-Proto https
        }
      }
    '';

    virtualHosts = {
      # Unprotected internal/core services
      "id.${domain}".extraConfig        = "reverse_proxy 127.0.0.1:1411";
      "auth.${domain}".extraConfig      = "reverse_proxy 127.0.0.1:3000";
      "jellyfin.${domain}".extraConfig  = "reverse_proxy 127.0.0.1:8096";
      "music.${domain}".extraConfig     = "reverse_proxy 127.0.0.1:4533";
      "arcane.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:3552";

      # Protected by TinyAuth SSO
      "deemix.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:6595";
      "slskd.${domain}".extraConfig     = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:5030";
      "sonarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8989";
      "radarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:7878";
      "lidarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8686";
      "bazarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:6767";
      "prowlarr.${domain}".extraConfig  = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:9696";
      "seerr.${domain}".extraConfig     = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:5055";
      "qbit.${domain}".extraConfig      = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8080";
      "archive.${domain}".extraConfig   = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8000";
      "aurral.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:3001";
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/caddy 0750 caddy caddy -"
  ];
  systemd.services.caddy.serviceConfig.EnvironmentFile = "/var/lib/caddy/.env";
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
