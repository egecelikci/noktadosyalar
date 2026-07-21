{ config, pkgs, ... }:

{
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/9421d165-b07b-43a3-897c-07ff63adbb15";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/media 0775 egecelikci media -"
    "d /mnt/media/Music 0775 egecelikci media -"
    "d /mnt/media/torrents 0775 egecelikci media -"
  ];
}
