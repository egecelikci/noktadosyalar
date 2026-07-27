{
  config,
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
  # sops.secrets."mautrix-discord/env" = { };
  # sops.secrets."mautrix-telegram/env" = { };
  # sops.secrets."mautrix-whatsapp/as_token" = { };
  # sops.secrets."mautrix-whatsapp/hs_token" = { };
  # sops.secrets."mautrix-whatsapp/pickle_key" = { };
  # sops.secrets."mautrix-whatsapp/provisioning_secret" = { };
  sops.secrets."pocket-id/env" = { };
  sops.secrets."qbittorrent/env" = { };
  sops.secrets."slskd/env" = { };
  sops.secrets."tinyauth/env" = { };
  # sops.secrets."matrix/mas_pocketid_secret" = {
  #   mode = "0444";
  #   owner = "continuwuity";
  # };
  # sops.secrets."matrix/mas_shared_secret" = { };
  # sops.secrets."matrix/mas_encryption" = { };
  # sops.secrets."matrix/mas_private_key" = {
  #   mode = "0444";
  # };

  # sops.templates."mautrix-whatsapp-config.yaml" = {
  #   content = builtins.toJSON {
  #     homeserver = {
  #       address = "http://127.0.0.1:8008";
  #       domain = "celikci.me";
  #       software = "standard";
  #     };
  #     appservice = {
  #       address = "http://127.0.0.1:29336";
  #       hostname = "0.0.0.0";
  #       port = 29336;
  #       id = "whatsapp";
  #       bot = {
  #         username = "whatsappbot";
  #         displayname = "WhatsApp";
  #       };
  #       ephemeral_events = true;
  #       username_template = "whatsapp_{{.}}";

  #       as_token = config.sops.placeholder."mautrix-whatsapp/as_token";
  #       hs_token = config.sops.placeholder."mautrix-whatsapp/hs_token";
  #     };
  #     bridge = {
  #       command_prefix = "!wa";
  #       personal_filtering_spaces = true;
  #       permissions = {
  #         "*" = "relay";
  #         "celikci.me" = "admin";
  #       };
  #     };
  #     database = {
  #       type = "sqlite3-fk-wal";
  #       uri = "file:/data/mautrix-whatsapp.db?_txlock=immediate";
  #     };
  #     encryption = {
  #       allow = true;
  #       default = true;
  #       msc4190 = true;
  #     };
  #     provisioning = {
  #       shared_secret = config.sops.placeholder."mautrix-whatsapp/provisioning_secret";
  #     };
  #   };
  #   mode = "0444";
  # };
}
