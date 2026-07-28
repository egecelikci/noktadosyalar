{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.mergerfs ];

  fileSystems."/mnt/disks/hdd" = {
    device = "/dev/disk/by-uuid/ce0ecdba-85d4-472b-a123-f636f73a8098";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };

  fileSystems."/mnt/disks/ssd" = {
    device = "/dev/disk/by-uuid/85f6b7c2-5e8e-4e56-9a90-1a6d4a1e14f5";
    fsType = "btrfs";
    options = [
      "subvol=@media-overflow"
      "compress=zstd"
      "noatime"
      "nofail"
    ];
  };

  fileSystems."/mnt/media" = {
    device = "/mnt/disks/hdd:/mnt/disks/ssd";
    fsType = "fuse.mergerfs";
    options = [
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=ff"
      "minfreespace=20G"
      "moveonenospc=true"
      "allow_other"
      "use_ino"
      "nofail"
    ];
    depends = [
      "/mnt/disks/hdd"
      "/mnt/disks/ssd"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/media 0775 egecelikci media -"
    "d /mnt/media/Music 0775 egecelikci media -"
    "d /mnt/media/torrents 0775 egecelikci media -"
    "d /mnt/media/Movies 0775 egecelikci media -"
    "d /mnt/media/TV 0775 egecelikci media -"
    "d /mnt/media/Anime 0775 egecelikci media -"
  ];
}
