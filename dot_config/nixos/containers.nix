{ config, lib, pkgs, ... }:

let
  domain    = "balcova.online";
  mediaRoot = "/mnt/media";
  homeDir   = "/home/egecelikci";
  net       = "media_network";
in
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

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

    deemix = {
      image = "local/deemix:latest";
      volumes = [
        "/var/lib/deemix:/config"
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
        "/var/lib/slskd:/app"
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
        "/var/lib/qbittorrent:/config"
      ];
    };

    audiomuse-ai-flask = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environment = {
        SERVICE_TYPE = "flask";
        POSTGRES_HOST = "host.docker.internal";
        POSTGRES_PORT = "5432";
        POSTGRES_USER = "audiomuse";
        POSTGRES_DB = "audiomuse";
      };
      environmentFiles = [ "${homeDir}/.config/containers/secrets/audiomuse.env" ];
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
      };
      environmentFiles = [ "${homeDir}/.config/containers/secrets/audiomuse.env" ];
      volumes = [ "${mediaRoot}/Music/Library:/music:ro" ];
      extraOptions = [ "--network=${net}" "--add-host=host.docker.internal:host-gateway" ];
    };

    recyclarr = {
      image = "ghcr.io/recyclarr/recyclarr:8";
      user = "1000:1000";
      volumes = [ "/var/lib/recyclarr:/config" ];
      environmentFiles = [ "${homeDir}/.config/containers/.env" ];
      extraOptions = [ "--network=${net}" ];
    };

  };
}
