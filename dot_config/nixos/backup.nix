{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.rclone ];

  services.restic.backups = {
    appdata = {
      repository = "rclone:Drive:restic";
      
      paths = [
        "/home/egecelikci/.config/deemix"
        "/home/egecelikci/.config/slskd"
        "/home/egecelikci/.config/qbittorrent"
        "/home/egecelikci/.config/prowlarr"
        "/home/egecelikci/.config/radarr"
        "/home/egecelikci/.local/share/audiomuse"
        "/home/egecelikci/.local/share/lrclib"
        "/home/egecelikci/.local/share/navidrome"
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
