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

    # ---- auth ----
    tinyauth = {
      image = "ghcr.io/tinyauthapp/tinyauth:v5";
      environmentFiles = [ "/run/secrets/tinyauth.env" ];
      extraOptions = [ "--network=${net}" ];
    };

    pocket-id = {
      image = "pocketid/pocket-id:v2";
      volumes = [ "${homeDir}/.local/share/pocket-id/data:/app/data" ];
      environmentFiles = [ "/run/secrets/pocket-id.env" ];
      extraOptions = [ "--network=${net}" ];
      dependsOn = [ ];
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
      environmentFiles = [ "/run/secrets/gluetun.env" ];
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--network=${net}"
      ];
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
      environmentFiles = [ "/run/secrets/slskd.env" ];
    };

    # ---- audiomuse-ai (workers only - db/redis now native, see native-services.nix) ----
    audiomuse-ai-flask = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environment = {
        SERVICE_TYPE = "flask";
        POSTGRES_HOST = "host-gateway";
        REDIS_URL = "redis://host-gateway:6380/0";
      };
      extraOptions = [ "--network=${net}" "--add-host=host-gateway:host-gateway" ];
    };

    audiomuse-ai-worker = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environment = {
        SERVICE_TYPE = "worker";
        POSTGRES_HOST = "host-gateway";
        REDIS_URL = "redis://host-gateway:6380/0";
      };
      volumes = [ "${mediaRoot}/Music/Library:/music:ro" ];
      extraOptions = [ "--network=${net}" "--add-host=host-gateway:host-gateway" ];
    };

    # ---- unpackaged apps, kept as-is ----
    seerr = {
      image = "ghcr.io/seerr-team/seerr:latest";
      environment = { TZ = "Europe/Istanbul"; PORT = "5055"; };
      volumes = [ "${homeDir}/.config/seerr:/app/config" ];
      extraOptions = [ "--network=${net}" ];
      # Only run this OR services.jellyseerr, not both - decide which fork you want.
    };

    archivebox = {
      image = "archivebox/archivebox:latest";
      volumes = [ "${homeDir}/.local/share/archivebox/data:/data" ];
      environment = {
        ALLOWED_HOSTS = "*";
        PUBLIC_ADD_VIEW = "False";
        SAVE_ARCHIVE_DOT_ORG = "False";
        MEDIA_MAX_SIZE = "5000m";
      };
      extraOptions = [ "--network=${net}" "--shm-size=1gb" ];
    };

    aurral = {
      image = "ghcr.io/lklynet/aurral:latest";
      environment = {
        TZ = "Europe/Istanbul";
        DOWNLOAD_FOLDER = "/downloads/aurral";
      };
      volumes = [
        "${mediaRoot}/Music/Downloads/Aurral:/downloads/aurral"
        "${homeDir}/.config/aurral/data:/app/backend/data"
      ];
      extraOptions = [ "--network=${net}" ];
    };

    arcane = {
      image = "ghcr.io/getarcaneapp/manager:latest";
      environmentFiles = [ "/run/secrets/arcane.env" ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "${homeDir}/.local/share/arcane/data:/app/data"
      ];
      extraOptions = [ "--network=${net}" "--cgroupns=host" ];
    };

    autoheal = {
      image = "willfarrell/autoheal:latest";
      environment.AUTOHEAL_CONTAINER_LABEL = "all";
      volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      extraOptions = [ "--network=${net}" ];
    };

    # ---- extras profile (optional in the original compose) ----
    minecraft = {
      image = "itzg/minecraft-server:latest";
      environment = {
        EULA = "TRUE";
        TYPE = "PAPER";
        VERSION = "26.2";
        MEMORY = "2G";
        TZ = "Europe/Istanbul";
      };
      volumes = [ "${homeDir}/.local/share/minecraft/data:/data" ];
      ports = [ "25565:25565" ];
      extraOptions = [ "--network=${net}" "--memory=3g" ];
    };

    playit = {
      image = "ghcr.io/playit-cloud/playit-agent:0.17";
      dependsOn = [ "minecraft" ];
      extraOptions = [ "--network=container:minecraft" ];
      environmentFiles = [ "/run/secrets/playit.env" ];
    };

  };
}
