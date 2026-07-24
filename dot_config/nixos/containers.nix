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
  net = "media_network";
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
      environmentFiles = [ config.sops.secrets."deemix/env".path ];
      extraOptions = [ "--network=${net}" ];
      ports = [ "127.0.0.1:6595:6595" ];
    };

    # lrclib = {
    #   image = "local/lrclib:latest";
    #   volumes = [ "${mediaRoot}/lrclib/data:/data" ];
    #   ports = [ "3300:3300" ];
    #   environment = {
    #     LRCLIB_LOG = "info";
    #     LRCLIB_MMAP_SIZE = "2000000000";
    #     LRCLIB_CACHE_SIZE = "-64000";
    #   };
    #   extraOptions = [ "--network=${net}" ];
    # };

    gluetun = {
      image = "qmcgaw/gluetun:latest";
      environmentFiles = [ config.sops.secrets."gluetun/env".path ];
      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--network=${net}"
        "--health-cmd=/gluetun-entrypoint healthcheck"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
        "--health-start-period=60s"
      ];
      ports = [
        "127.0.0.1:5030:5030"
        "127.0.0.1:8080:8080"
      ];
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
      environmentFiles = [ config.sops.secrets."slskd/env".path ];
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
      environmentFiles = [ config.sops.secrets."qbittorrent/env".path ];
      volumes = [
        "${mediaRoot}/torrents:/data/torrents"
        "/var/lib/qbittorrent:/config"
      ];
    };

    audiomuse-ai-flask = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environmentFiles = [ config.sops.secrets."audiomuse/env".path ];
      extraOptions = [
        "--network=${net}"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };

    audiomuse-ai-worker = {
      image = "ghcr.io/neptunehub/audiomuse-ai:latest";
      environmentFiles = [ config.sops.secrets."audiomuse/env".path ];
      volumes = [ "${mediaRoot}/Music/Library:/music:ro" ];
      extraOptions = [
        "--network=${net}"
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };
}
