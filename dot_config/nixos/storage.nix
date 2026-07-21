{ config, pkgs, ... }:

{
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/ce0ecdba-85d4-472b-a123-f636f73a8098";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/media 0775 egecelikci media -"
    "d /mnt/media/Music 0775 egecelikci media -"
    "d /mnt/media/torrents 0775 egecelikci media -"
  ];
}
