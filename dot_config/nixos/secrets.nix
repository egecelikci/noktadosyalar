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
        # Placeholder — nix will refuse to build and print the correct sha256
        # the first time you run nixos-rebuild. Paste that value in, or
        # pre-compute it yourself with:
        #   nix-shell -p nix-prefetch-git --run \
        #     'nix-prefetch-url --unpack https://github.com/Mic92/sops-nix/archive/f1406619a3884cd5c47992a70b8b35c9c0fcb4c9.tar.gz'
        sha256 = "1iswdpzlyngqlipy14mjmpazx9yybvidpm4sfk74ww9jg3r849b8";
      }
    }/modules/sops"
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # sunucu's own SSH host key can double as its sops/age identity, so
  # there's nothing new to provision — see the .sops.yaml + key-derivation
  # steps below.

  sops.secrets."tinyauth/env" = {
    # sops-nix writes this out to /run/secrets/tinyauth/env at activation,
    # owned root:root 0400 by default. Point the service at that path
    # instead of ~/.config/containers/secrets/tinyauth.env.
  };
  sops.secrets."pocket-id/env" = { };
  sops.secrets."gluetun/env" = { };
  sops.secrets."slskd/env" = { };
  sops.secrets."qbittorrent/env" = { };
  sops.secrets."cloudflare-acme/env" = { };
  sops.secrets."cloudflared/env" = { };
  sops.secrets."audiomuse/env" = { };

  # Deliberately NOT here: restic/env, restic/password. Those stay sourced
  # from Bitwarden via chezmoi (bitwardenSecrets .bitwarden.restic_password_id,
  # same as executable_restore-sunucu.sh.tmpl already does). If restic's own
  # credentials were sops secrets, restoring a dead box would require
  # /var/lib/sops-nix/key.txt to already exist to decrypt them — but that
  # file's only backup would be inside the restic repo you're trying to
  # open. Keeping restic's bootstrap path independent of sops breaks that
  # loop. Back up the age key itself to Bitwarden by hand after generating
  # it (see chat) rather than relying solely on restic sweeping it up.
}
