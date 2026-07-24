{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = "balcova.online";
  mediaRoot = "/mnt/media";
  homeDir = "/home/egecelikci";
  mediaUser = "media";
  mediaGroup = "media";
in
{
  users.groups.${mediaGroup} = { };
  users.users.${mediaUser} = {
    isSystemUser = true;
    group = mediaGroup;
    extraGroups = [
      "render"
      "video"
    ];
  };

  services.cloudflared = {
    enable = true;
    tunnels."1404537c-f758-400b-a044-e7ed1f70334f" = {
      credentialsFile = "${homeDir}/.config/cloudflared/tunnel-credentials.json";
      default = "http_status:404";
      ingress = {
        "*.balcova.online" = "http://127.0.0.1:80";
        "balcova.online" = "http://127.0.0.1:80";
      };
    };
  };

  services.tinyauth = {
    enable = true;
    environmentFile = "${homeDir}/.config/containers/secrets/tinyauth.env";
    settings = {
      APPURL = "https://auth.balcova.online";
      OAUTH_AUTOREDIRECT = "pocketid";
      OAUTH_PROVIDERS_POCKETID_AUTHURL = "https://id.balcova.online/authorize";
      OAUTH_PROVIDERS_POCKETID_TOKENURL = "http://127.0.0.1:1411/api/oidc/token";
      OAUTH_PROVIDERS_POCKETID_USERINFOURL = "http://127.0.0.1:1411/api/oidc/userinfo";
      OAUTH_PROVIDERS_POCKETID_REDIRECTURL = "https://auth.balcova.online/api/oauth/callback/pocketid";
      OAUTH_PROVIDERS_POCKETID_SCOPES = "openid email profile groups";
      OAUTH_PROVIDERS_POCKETID_NAME = "Pocket ID";
    };
  };

  services.pocket-id = {
    enable = true;
    environmentFile = "${homeDir}/.config/containers/secrets/pocket-id.env";
    settings = {
      APP_URL = "https://id.balcova.online";
      TRUST_PROXY = true;
      HOST = "127.0.0.1";
      PORT = 1411;
    };
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
      "Plugins.Folder" = "/var/lib/navidrome/plugins";
    };
  };
  systemd.services.navidrome.serviceConfig.EnvironmentFile =
    "${homeDir}/.config/navidrome/navidrome.env";

  systemd.services.recyclarr = {
    description = "Recyclarr Sync";
    after = [
      "network.target"
      "radarr.service"
      "sonarr.service"
    ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.recyclarr}/bin/recyclarr sync --config /var/lib/recyclarr/configs/radarr.yml
      ${pkgs.recyclarr}/bin/recyclarr sync --config /var/lib/recyclarr/configs/sonarr.yml
    '';
    serviceConfig = {
      Type = "oneshot";
      User = mediaUser;
      Environment = [
        "RECYCLARR_CONFIG_DIR=/var/lib/recyclarr"
      ];
      EnvironmentFile = "-/var/lib/recyclarr/env";
    };
  };

  services.prowlarr.enable = true;
  services.radarr = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    # openFirewall = false;
  };
  services.sonarr = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
  };
  services.bazarr = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
  };
  services.lidarr = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
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
    ensureUsers = [
      {
        name = "audiomuse";
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
    requirePassFile = "${homeDir}/.config/redis/audiomuse-password";
  };

  networking.firewall.interfaces.docker0.allowedTCPPorts = [
    5432
    6380
  ];

  networking.hosts = {
    "127.0.0.1" = [
      "jellyfin"
      "radarr"
      "sonarr"
      "lidarr"
      "prowlarr"
    ];
  };

  services.caddy = {
    enable = true;

    globalConfig = ''
      email ege@celikci.me
      servers {
          protocols h1 h2
      }
    '';

    extraConfig = ''
      http://balcova.online {
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

    virtualHosts."http://*.balcova.online" = {
      extraConfig = ''
        @id host id.balcova.online
        handle @id {
          reverse_proxy 127.0.0.1:1411
        }

        @auth host auth.balcova.online
        handle @auth {
          reverse_proxy 127.0.0.1:3000
        }

        @music host music.balcova.online
        handle @music {
          reverse_proxy 127.0.0.1:4533
        }

        # --- Protected Apps ---
        @deemix host deemix.balcova.online
        handle @deemix {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:6595
        }

        @slskd host slskd.balcova.online
        handle @slskd {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:5030
        }

        @sonarr host sonarr.balcova.online
        handle @sonarr {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:8989
        }

        @radarr host radarr.balcova.online
        handle @radarr {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:7878
        }

        @lidarr host lidarr.balcova.online
        handle @lidarr {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:8686
        }

        @bazarr host bazarr.balcova.online
        handle @bazarr {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:6767
        }

        @prowlarr host prowlarr.balcova.online
        handle @prowlarr {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:9696
        }

        @seerr host seerr.balcova.online
        handle @seerr {
          reverse_proxy 127.0.0.1:5055
        }

        @qbit host qbit.balcova.online
        handle @qbit {
          import tinyauth_forwarder
          reverse_proxy 127.0.0.1:8080
        }

        @jellyfin host jellyfin.balcova.online
        handle @jellyfin {
          reverse_proxy 127.0.0.1:8096 {
          }
        }
      '';
    };
  };
}
