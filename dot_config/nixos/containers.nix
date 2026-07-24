# media-stack/containers.nix
#
# Everything left over: custom-built images, or apps that just aren't packaged
# in nixpkgs. Kept on Docker via virtualisation.oci-containers so you don't have
# to fight custom Dockerfiles into Nix derivations tonight. Swap backend to
# "podman" later if you want - it's the more idiomatic NixOS choice, but Docker
# is a smaller diff from what you already have.

{ config, lib, pkgs, ... }:

let
  domain    = "balcova.online";
  mediaRoot = "/mnt/media";
  homeDir   = "/home/egecelikci"; # CHANGE if the new user/home differs
  net       = "media_network";
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # docker-compose created this network implicitly; oci-containers doesn't,
  # so create it once before any container tries to join it.
  systemd.services.docker-network-media = {
    description = "Ensure the ${net} docker network exists";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    script = ''
      ${pkgs.docker}/bin/docker network inspect ${net} >/dev/null 2>&1 || \
        ${pkgs.docker}/bin/docker network create ${net}
    '';
  };

  virtualisation.oci-containers.containers = {

    cloudflared = {
      image = "cloudflare/cloudflared:latest";
      cmd = [ "tunnel" "run" ];
      environmentFiles = [ "${homeDir}/.config/containers/secrets/cloudflared.env" ];
      extraOptions = [ "--network=host" ];
    };

    # ---- auth ----
    tinyauth = {
      image = "ghcr.io/tinyauthapp/tinyauth:v5";
      environment = {
        TINYAUTH_APPURL = "https://auth.${domain}";
        TINYAUTH_OAUTH_AUTOREDIRECT = "pocketid";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_AUTHURL = "https://id.${domain}/authorize";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_TOKENURL = "http://pocket-id:1411/api/oidc/token";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_USERINFOURL = "http://pocket-id:1411/api/oidc/userinfo";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_REDIRECTURL = "https://auth.${domain}/api/oauth/callback/pocketid";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_SCOPES = "openid email profile groups";
        TINYAUTH_OAUTH_PROVIDERS_POCKETID_NAME = "Pocket ID";
      };
      # CLIENTID/CLIENTSECRET only - see dot_config/containers/secrets/private_tinyauth.env.tmpl
      environmentFiles = [ "${homeDir}/.config/containers/secrets/tinyauth.env" ];
      extraOptions = [ "--network=${net}" ];
      ports = [ "127.0.0.1:3000:3000" ];
    };

    pocket-id = {
      image = "pocketid/pocket-id:v2";
      environment = {
        APP_URL = "https://id.${domain}";
        TRUST_PROXY = "true";
        TRUSTED_PLATFORM = "CF-Connecting-IP";
        SMTP_HOST = "mail.smtp2go.com";
        SMTP_PORT = "2525";
        SMTP_TLS = "starttls";
        SMTP_FROM = "auth@${domain}";
        SMTP_USER = "ege";
        TZ = "Europe/Istanbul";
        PUID = "1000";
        PGID = "1000";
      };
      volumes = [ "${homeDir}/.local/share/pocket-id/data:/app/data" ];
      # ENCRYPTION_KEY/SMTP_PASSWORD only - see private_pocket-id.env.tmpl
      environmentFiles = [ "${homeDir}/.config/containers/secrets/pocket-id.env" ];
      extraOptions = [ "--network=${net}" ];
      dependsOn = [ ];
      ports = [ "127.0.0.1:1411:1411" ];
    };

    # ---- music download/library pipeline ----
    # deemix and lrclib both used `build:` in the compose file (a local Dockerfile
    # and a git-cloned Dockerfile respectively). oci-containers only pulls
    # pre-built images - it has no `build:` equivalent. Two options:
    #   1. `docker build -t local/deemix:latest .` by hand on the new box and
    #      reference that tag here (simplest, what's assumed below).
    #   2. Package it properly as a Nix derivation with dockerTools - worth doing
    #      later, not tonight.
    deemix = {
      image = "local/deemix:latest";
      volumes = [
        "${homeDir}/.config/deemix:/config"
        "${mediaRoot}/Music/Downloads/Deemix:/downloads"
      ];
      environment.DEEMIX_SINGLE_USER = "true";
      extraOptions = [ "--network=${net}" ];
      ports = [ "127.0.0.1:6595:6595" ];
    };

    lrclib = {
      image = "local/lrclib:latest";
      volumes = [ "${mediaRoot}/lrclib/data:/data" ];
      ports = [ "3300:3300" ];
      environment = {
        LRCLIB_LOG = "info";
        LRCLIB_MMAP_SIZE = "2000000000";
        LRCLIB_CACHE_SIZE = "-64000";
      };
      extraOptions = [ "--network=${net}" ];
    };

    # ---- gluetun + slskd (VPN-confined) ----
    # qbittorrent moved to the native module in native-services.nix, which is the
    # one real complication: it can no longer share gluetun's network namespace
    # the way `network_mode: service:gluetun` did. Two real options, pick one:
    #   a) Keep qbittorrent as a container too (network_mode: container:gluetun,
    #      same pattern as slskd below) instead of using services.qbittorrent.
    #   b) Route qbittorrent's systemd service through a wireguard network
    #      namespace directly (systemd.services.qbittorrent.bindsTo / a netns
    #      unit) instead of gluetun. More native, more setup.
    # Given you already have working gluetun+ProtonVPN port-forwarding config,
    # (a) is the low-risk move - don't fix what isn't broken on this piece.
    gluetun = {
      image = "qmcgaw/gluetun:latest";
      environment = {
        VPN_SERVICE_PROVIDER = "protonvpn";
        VPN_TYPE = "wireguard";
        VPN_PORT_FORWARDING = "on";
        VPN_PORT_FORWARDING_PROVIDER = "protonvpn";
        PORT_FORWARD_ONLY = "on";
        SERVER_COUNTRIES = "Turkey";
        HTTP_CONTROL_SERVER_ADDRESS = ":8000";
        FIREWALL_INPUT_PORTS = "8080,5030";
      };
      # WIREGUARD_PRIVATE_KEY/HTTP_CONTROL_SERVER_AUTH_DEFAULT_ROLE - see private_gluetun.env.tmpl
      environmentFiles = [ "${homeDir}/.config/containers/secrets/gluetun.env" ];
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--network=${net}"
        "--health-cmd=/gluetun-entrypoint healthcheck"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
        "--health-start-period=60s"
      ];
      ports = [ "127.0.0.1:5030:5030" "127.0.0.1:8080:8080" ];
    };

    slskd = {
      image = "slskd/slskd:latest";
      dependsOn = [ "gluetun" ];
      extraOptions = [ "--network=container:gluetun" ];
      volumes = [
        "${homeDir}/.config/slskd:/app"
        "${mediaRoot}/Music/Downloads/Soulseek:/downloads"
        "${mediaRoot}/Music/Library:/music:ro"
      ];
      environment = {
        SLSKD_NO_AUTH = "true";
        SLSKD_DOWNLOADS_DIR = "/downloads";
        SLSKD_REMOTE_CONFIGURATION = "true";
        SLSKD_SHARED_DIR = "/music";
        SLSKD_VPN = "true";
        SLSKD_VPN_PORT_FORWARDING = "true";
        SLSKD_VPN_GLUETUN_URL = "http://localhost:8000";
      };
      # SLSKD_SLSK_USERNAME/PASSWORD, SLSKD_VPN_GLUETUN_API_KEY, SLSKD_API_KEY - see private_slskd.env.tmpl
      environmentFiles = [ "${homeDir}/.config/containers/secrets/slskd.env" ];
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      dependsOn = [ "gluetun" ];
      extraOptions = [ "--network=container:gluetun" ];
      environment = {
        TZ = "Europe/Istanbul";
        PUID = "1000";
        PGID = "1000";
        WEBUI_PORT = "8080";
        DOCKER_MODS = "ghcr.io/t-anc/gsp-qbittorent-gluetun-sync-port-mod:main";
        GSP_MINIMAL_LOGS = "false";
      };
      environmentFiles = [ "${homeDir}/.config/containers/secrets/qbittorrent.env" ];
      volumes = [
        "${mediaRoot}/torrents:/data/torrents"
        "${homeDir}/.config/qbittorrent:/config"
      ];
    };

    audiomuse-ai-flask = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environment = {
        SERVICE_TYPE = "flask";
        POSTGRES_HOST = "host.docker.internal";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "audiomuse";
        POSTGRES_DB = "audiomuse";       # matches the renamed Nix database
        REDIS_URL = "redis://host.docker.internal:6380/0";
      };
      environmentFiles = [ "${homeDir}/.config/containers/secrets/audiomuse.env" ]; # POSTGRES_PASSWORD only
      extraOptions = [ "--network=${net}" "--add-host=host.docker.internal:host-gateway" ];
    };

    audiomuse-ai-worker = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environment = {
        SERVICE_TYPE = "worker";
        POSTGRES_HOST = "host.docker.internal";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "audiomuse";
        POSTGRES_DB = "audiomuse";
        REDIS_URL = "redis://host.docker.internal:6380/0";
      };
      environmentFiles = [ "${homeDir}/.config/containers/secrets/audiomuse.env" ];
      volumes = [ "${mediaRoot}/Music/Library:/music:ro" ];
      extraOptions = [ "--network=${net}" "--add-host=host.docker.internal:host-gateway" ];
    };

    recyclarr = {
      image = "ghcr.io/recyclarr/recyclarr:8";
      user = "1000:1000";
      volumes = [ "${homeDir}/.config/recyclarr:/config" ];
      environmentFiles = [ "${homeDir}/.config/containers/.env" ];
      extraOptions = [ "--network=${net}" ];
    };

  };
}
