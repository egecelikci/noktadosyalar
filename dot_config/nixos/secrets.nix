{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    "${
      builtins.fetchTarball {
        url = "https://github.com/Mic92/sops-nix/archive/f1406619a3884cd5c47992a70b8b35c9c0fcb4c9.tar.gz";
        sha256 = "1iswdpzlyngqlipy14mjmpazx9yybvidpm4sfk74ww9jg3r849b8";
      }
    }/modules/sops"
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  sops.secrets."audiomuse/env" = { };
  sops.secrets."cloudflare-acme/env" = { };
  sops.secrets."cloudflared/env" = { };
  sops.secrets."deemix/env" = { };
  sops.secrets."gluetun/env" = { };
  sops.secrets."mautrix-discord/env" = { };
  sops.secrets."mautrix-telegram/env" = { };
  sops.secrets."mautrix-whatsapp/env" = { };
  sops.secrets."pocket-id/env" = { };
  sops.secrets."qbittorrent/env" = { };
  sops.secrets."slskd/env" = { };
  sops.secrets."tinyauth/env" = { };
  sops.secrets."matrix/mas_pocketid_secret" = {
    mode = "0444";
    owner = "continuwuity";
  };
  sops.secrets."matrix/mas_shared_secret" = { };
  sops.secrets."matrix/mas_encryption" = { };
  sops.secrets."matrix/mas_private_key" = {
    mode = "0444";
  };
}
