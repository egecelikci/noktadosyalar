{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.matrix-continuwuity = {
    enable = true;
    settings = {
      global = {
        server_name = "celikci.me";
        port = [ 8008 ];
        well_known = {
          client = "https://matrix.balcova.online";
          server = "matrix.balcova.online:443";
        };
        allow_registration = false;
        allow_local_passwords = false;
        oauth = {
          compatibility_mode = "exclusive";
          oidc = {
            enabled = true;
            discovery_url = "https://id.balcova.online";
            client_id = "a932662b-fd47-46c4-a573-4b820283b95a";
            client_secret_file = config.sops.secrets."matrix/mas_pocketid_secret".path;
          };
        };
      };
    };
  };

  services.mautrix-discord = {
    enable = true;
    environmentFile = config.sops.secrets."mautrix-discord/env".path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = "celikci.me";
      };
      appservice = {
        address = "http://127.0.0.1:29334";
        hostname = "127.0.0.1";
        port = 29334;
        database = {
          type = "sqlite3-fk-wal";
          uri = "file:/var/lib/mautrix-discord/mautrix-discord.db?_txlock=immediate";
        };
      };
      encryption = {
        allow = true;
        default = true;
      };
      bridge = {
        personal_filtering_spaces = true;
        permissions = {
          "celikci.me" = "admin";
        };
      };
    };
  };

  services.mautrix-telegram = {
    enable = true;
    environmentFile = config.sops.secrets."mautrix-telegram/env".path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = "celikci.me";
      };
      appservice = {
        address = "http://127.0.0.1:29335";
        hostname = "127.0.0.1";
        port = 29335;
        database = "sqlite:////var/lib/mautrix-telegram/mautrix-telegram.db";
      };
      telegram = {
        api_id = 2010259;
        api_hash = "8c8ef5982a0a5e3049ad70db4802055c";
      };
      encryption = {
        allow = true;
        default = true;
      };
      bridge = {
        personal_filtering_spaces = true;
        permissions = {
          "celikci.me" = "admin";
        };
      };
    };
  };

  virtualisation.oci-containers.containers = {
    element = {
      image = "vectorim/element-web:latest";
      ports = [ "127.0.0.1:8082:80" ];
      environment = {
        VECTOR_DEFAULT_HS_URL = "https://matrix.balcova.online";
      };
      volumes = [
        "/var/lib/element/config.json:/app/config.json:ro"
      ];
    };

    mautrix-whatsapp = {
      image = "dock.mau.dev/mautrix/whatsapp:latest";
      volumes = [
        "/var/lib/mautrix-whatsapp:/data"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.services."docker-mautrix-whatsapp".preStart = lib.mkAfter ''
    mkdir -p /var/lib/mautrix-whatsapp
    cp -f ${
      config.sops.templates."mautrix-whatsapp-config.yaml".path
    } /var/lib/mautrix-whatsapp/config.yaml

    # Hand ownership to the mautrix container user (UID 1337)
    chown -R 1337:1337 /var/lib/mautrix-whatsapp
    chmod 644 /var/lib/mautrix-whatsapp/config.yaml
  '';
}
