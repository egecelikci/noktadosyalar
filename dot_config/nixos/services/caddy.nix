{ config, pkgs, ... }:

let
  caddyRoutes = ''
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
      @api {
        path /api/* /ping
        expression `{header.X-Api-Key} != "" || {query.apikey} != ""`
      }
      handle @api { reverse_proxy 127.0.0.1:8989 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:8989
      }
    }

    @radarr host radarr.balcova.online
    handle @radarr {
      @api {
        path /api/* /ping
        expression `{header.X-Api-Key} != "" || {query.apikey} != ""`
      }
      handle @api { reverse_proxy 127.0.0.1:7878 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:7878
      }
    }

    @lidarr host lidarr.balcova.online
    handle @lidarr {
      @api {
        path /api/* /ping
        expression `{header.X-Api-Key} != "" || {query.apikey} != ""`
      }
      handle @api { reverse_proxy 127.0.0.1:8686 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:8686
      }
    }

    @bazarr host bazarr.balcova.online
    handle @bazarr {
      @api {
        path /api/* /ping
        expression `{header.X-Api-Key} != "" || {query.apikey} != ""`
      }
      handle @api { reverse_proxy 127.0.0.1:6767 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:6767
      }
    }

    @prowlarr host prowlarr.balcova.online
    handle @prowlarr {
      @api {
        path /api/* /ping
        expression `{header.X-Api-Key} != "" || {query.apikey} != ""`
      }
      handle @api { reverse_proxy 127.0.0.1:9696 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:9696
      }
    }

    @seerr host seerr.balcova.online
    handle @seerr {
      reverse_proxy 127.0.0.1:5055
    }

    @qbit host qbit.balcova.online
    handle @qbit {
      @qbitApi { path /api/* }
      handle @qbitApi { reverse_proxy 127.0.0.1:8080 }
      handle {
        import tinyauth_forwarder
        reverse_proxy 127.0.0.1:8080
      }
    }

    @jellyfin host jellyfin.balcova.online
    handle @jellyfin {
      reverse_proxy 127.0.0.1:8096
    }
  '';
in
{
  services.cloudflared = {
    enable = true;
    tunnels."1404537c-f758-400b-a044-e7ed1f70334f" = {
      credentialsFile = "/home/egecelikci/.config/cloudflared/tunnel-credentials.json";
      default = "http_status:404";
      ingress = {
        "*.balcova.online" = "http://127.0.0.1:80";
        "balcova.online" = "http://127.0.0.1:80";
        "matrix.celikci.me" = "http://127.0.0.1:80";
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "ege@celikci.me";
    certs."balcova.online" = {
      domain = "*.balcova.online";
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets."cloudflare-acme/env".path;
      group = "caddy";
    };
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
      (tinyauth_forwarder) {
        forward_auth 127.0.0.1:3000 {
          uri /api/auth/caddy
          copy_headers Remote-User Remote-Name Remote-Email Remote-Groups
          header_up X-Forwarded-Proto https
        }
      }
    '';

    virtualHosts."*.balcova.online" = {
      useACMEHost = "balcova.online";
      extraConfig = caddyRoutes;
    };

    virtualHosts."http://*.balcova.online" = {
      listenAddresses = [ "127.0.0.1" ];
      extraConfig = caddyRoutes;
    };

    # Matrix reverse proxy block
    # virtualHosts."matrix.celikci.me" = {
    #   extraConfig = ''
    #     reverse_proxy /_matrix/client/v3/login* 127.0.0.1:8080
    #     reverse_proxy /_matrix/client/unstable/org.matrix.msc3882/login* 127.0.0.1:8080
    #     reverse_proxy /_matrix/client/v3/logout* 127.0.0.1:8080
    #     reverse_proxy /_matrix/client/v3/refresh* 127.0.0.1:8080
    #
    #     reverse_proxy 127.0.0.1:8008
    #   '';
    # };
  };
}
