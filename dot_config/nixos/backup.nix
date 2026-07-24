{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.rclone
    pkgs.restic
  ];

  services.restic.backups = {
    appdata = {
      repository = "rclone:Drive:restic";

      paths = [
        "/var/lib"
      ];

      extraOptions = [
        "exclude=/var/lib/docker"
        "exclude=/var/lib/systemd"
        "exclude=/var/lib/containers"
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
