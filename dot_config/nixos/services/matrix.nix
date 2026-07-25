{ config, pkgs, ... }:

{
  # 1. Generate the MAS config securely using SOPS templating
  sops.templates."mas-config.yaml" = {
    content = ''
      matrix:
        homeserver: "celikci.me"
        endpoint: "http://127.0.0.1:8008"
      database:
        uri: "postgresql://mas@host.docker.internal/mas"
      upstream_oauth2:
        providers:
          - id: "pocket-id"
            issuer: "https://id.balcova.online"
            client_id: "a932662b-fd47-46c4-a573-4b820283b95a"
            client_secret: "${config.sops.placeholder."matrix/mas_pocketid_secret"}"
            scope: "openid profile email"
    '';
  };

  services.matrix-continuwuity = {
    enable = true;
    settings = {
      global = {
        server_name = "celikci.me";

        well_known = {
          client = "https://matrix.celikci.me";
          server = "matrix.celikci.me:443";
        };

        allow_registration = false;
        allow_local_passwords = false;
      };
    };
  };

  # 3. Run MAS inside an OCI container to bypass the missing 26.11 module
  virtualisation.oci-containers.containers.mas = {
    image = "ghcr.io/element-hq/matrix-authentication-service:latest";
    extraOptions = [
      "--add-host=host.docker.internal:host-gateway"
    ];
    volumes = [
      # Mount the securely templated config into the container
      "${config.sops.templates."mas-config.yaml".path}:/config.yaml:ro"
    ];
    ports = [ "127.0.0.1:8080:8080" ];
  };
}
