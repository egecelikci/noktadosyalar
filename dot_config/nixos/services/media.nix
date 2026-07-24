{ config, pkgs, ... }:

let
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
      Environment = [ "RECYCLARR_CONFIG_DIR=/var/lib/recyclarr" ];
      EnvironmentFile = "/var/lib/recyclarr/env";

      # Security Hardening
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/var/lib/recyclarr" ];
    };
  };

  services.prowlarr.enable = true;
  services.radarr = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
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

  networking.hosts = {
    "127.0.0.1" = [
      "jellyfin"
      "radarr"
      "sonarr"
      "lidarr"
      "prowlarr"
    ];
  };
}
