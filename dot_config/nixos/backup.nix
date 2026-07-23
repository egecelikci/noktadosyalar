{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.rclone ];

  services.restic.backups = {
    appdata = {
      repository = "rclone:Drive:restic";
      
      paths = [
        # Still on virtualisation.oci-containers (containers.nix) — same
        # $HOME layout as the old macOS compose stack.
        "/home/egecelikci/.config/deemix"
        "/home/egecelikci/.config/slskd"
        "/home/egecelikci/.config/recyclarr"
        "/home/egecelikci/.config/aurral"
        "/home/egecelikci/.local/share/pocket-id"
        "/home/egecelikci/.local/share/archivebox"
        "/home/egecelikci/.local/share/arcane"
        "/home/egecelikci/.local/share/audiomuse"
        "/home/egecelikci/.local/share/lrclib"

        # Native NixOS modules (native-services.nix) — state lives under
        # /var/lib/<service> now, not ~/.config/<service>.
        "/var/lib/radarr/.config/Radarr"
        "/var/lib/sonarr/.config/Sonarr"
        "/var/lib/lidarr/.config/Lidarr"
        "/var/lib/bazarr"     # verify against `systemctl cat bazarr` — no dataDir option upstream
        "/var/lib/prowlarr"
        "/var/lib/jellyfin"
        "/var/lib/seerr"      # verify this is your seerr module's actual state-dir name
        "/var/lib/qbittorrent"
        "/var/lib/navidrome"
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
