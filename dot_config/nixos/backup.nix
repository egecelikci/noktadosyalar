{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.rclone pkgs.restic ];

  services.restic.backups = {
    appdata = {
      repository = "rclone:Drive:restic";

      paths = [
        "/home/egecelikci/.config/aurral"
        "/home/egecelikci/.config/deemix"
        "/home/egecelikci/.config/qbittorrent"
        "/home/egecelikci/.config/recyclarr"
        "/home/egecelikci/.config/slskd"
        "/home/egecelikci/.local/share/audiomuse"
        "/home/egecelikci/.local/share/lrclib"
        "/home/egecelikci/.local/share/pocket-id"
        "/var/lib/bazarr"
        "/var/lib/jellyfin"
        "/var/lib/lidarr/.config/Lidarr"
        "/var/lib/navidrome"
        "/var/lib/prowlarr"
        "/var/lib/radarr/.config/Radarr"
        "/var/lib/seerr"
        "/var/lib/sonarr/.config/Sonarr"
      ];

      environmentFile = "/home/egecelikci/.config/restic/restic-env";
      passwordFile = "/home/egecelikci/.config/restic/restic-password";

      timerConfig = {
        OnCalendar = "*-*-* 04:00:00";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
    };
  };
}
