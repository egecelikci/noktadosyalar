# media-stack/native-services.nix
#
# Replaces the docker-compose services that have real NixOS modules.
# Import this from configuration.nix:
#   imports = [ ./hardware-configuration.nix ./media-stack/native-services.nix ./media-stack/containers.nix ];
#
# Confidence key (checked this session against search.nixos.org / mynixos.com,
# channel unstable, 2026-07-21):
#   [VERIFIED]  option path confirmed to exist
#   [ASSUMED]   long-standing module, existence is near-certain, exact option
#               names not re-checked this session — run `nixos-option services.X`
#               or check search.nixos.org for your actual channel before building

{ config, lib, pkgs, ... }:

let
  domain    = "balcova.online";
  # CHANGE: point this at wherever the media pool is mounted on the new box.
  mediaRoot = "/mnt/media";
  homeDir   = "/home/egecelikci"; # CHANGE if the new user/home differs - matches containers.nix
  mediaUser = "media";
  mediaGroup = "media";
in
{
  users.groups.${mediaGroup} = {};
  users.users.${mediaUser} = {
    isSystemUser = true;
    group = mediaGroup;
    extraGroups = [ "render" "video" ];
  };

  # ---- Jellyfin [ASSUMED - stable module for years] ----
  services.jellyfin = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    openFirewall = false; # Caddy fronts it, no need to expose 8096 directly
  };

  # ---- Navidrome [ASSUMED] ----
  services.navidrome = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "${mediaRoot}/Music/Library";
      LogLevel = "info";
      EnableSharing = true;
      Agents = "audiomuseai,listenbrainz,apple-music,deezer";
      Scanner.ScanSchedule = "@every 1h";
    };
  };
  # LastFM key/secret are secrets, not settings -> inject via env file
  systemd.services.navidrome.serviceConfig.EnvironmentFile = "${homeDir}/.config/navidrome/navidrome.env";
  # navidrome.env is chezmoi-managed - see dot_config/navidrome/private_navidrome.env.tmpl

  # ---- *arr stack [ASSUMED - long-standing modules] ----
  services.prowlarr.enable = true;
  services.radarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.sonarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.bazarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  services.lidarr  = { enable = true; user = mediaUser; group = mediaGroup; };
  # Lidarr on the "develop" tag in the compose file (for the extra plugin support you
  # found) has no equivalent in nixpkgs' stable package by default. If you need the
  # develop branch behaviour, override the package:
  #   services.lidarr.package = pkgs.lidarr; # check nixpkgs for a -develop variant/override

  # ---- qbittorrent [VERIFIED: services.qbittorrent exists, unstable] ----
  # NOTE: in the compose file this ran with network_mode: service:gluetun (VPN-only).
  # The native module has no netns option. See containers.nix + README for the
  # VPN-confinement approach — this is the one piece that genuinely doesn't port cleanly.
  services.qbittorrent = {
    enable = true;
    user = mediaUser;
    group = mediaGroup;
    webuiPort = 8080;
    torrentingPort = 50413; # pick a fixed port, forward it through your VPN provider
    openFirewall = false;
  };

  # ---- flaresolverr [VERIFIED] ----
  services.flaresolverr = {
    enable = true;
    # openFirewall = false; # not exposed publicly in the original stack either
  };

  # ---- jellyseerr [VERIFIED] ----
  # Careful: the compose file used "seerr" (ghcr.io/seerr-team/seerr), a different
  # fork from jellyseerr. jellyseerr is the one with a nixpkgs module; seerr is not
  # packaged. Decide if jellyseerr is an acceptable substitute or keep seerr as a
  # container (see containers.nix).
  services.seerr = {
    enable = true;
    port = 5055;
    openFirewall = false;
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = [ "audiomuse" ];
    ensureUsers = [{
      name = "audiomuse";
      ensureDBOwnership = true;
    }];
    authentication = ''
      host  audiomuse  audiomuse  172.16.0.0/12  scram-sha-256
    '';
  };
  # ensureUsers never sets a password — do it once:
  #   sudo -u postgres psql -c "ALTER ROLE audiomuse WITH PASSWORD '...';"

  services.redis.servers.audiomuse = {
    enable = true;
    port = 6380;
    bind = "0.0.0.0"; # 127.0.0.1 is unreachable from the docker network — see below
    settings.requirepass = "..."; # pull from the same secret as postgres
  };

  networking.firewall.interfaces.docker0.allowedTCPPorts = [ 5432 6380 ];

  # ---- minecraft [ASSUMED, module exists] ----
  # The compose file uses itzg/minecraft-server with TYPE=PAPER and auto-downloads
  # the jar. The native module wants an actual pkgs derivation for the server -
  # nixpkgs doesn't reliably track bleeding-edge PaperMC builds. Since this was
  # already behind `profiles: ["extras"]` (i.e. optional), recommend leaving it as
  # a container rather than fighting the native module for marginal benefit.
  # See containers.nix.

<<<<<<< HEAD
<<<<<<< Updated upstream
  # ---- cloudflared [VERIFIED: services.cloudflared exists] ----
  # credentialsFile needs a real locally-managed tunnel credentials JSON, not
  # the CLOUDFLARE_TUNNEL_TOKEN the old compose stack ran with (that's the
  # remotely-managed/dashboard mode, a different auth path entirely). The
  # right secret was already sitting unused in .chezmoidata.yaml as
  # cf_tunnel_credentials_id - templated now, see
  # dot_config/cloudflared/private_tunnel-credentials.json.tmpl.
  services.cloudflared = {
    enable = true;
    tunnels."d088e974-c28b-419c-be94-148215f30b69" = {
      credentialsFile = "${homeDir}/.config/cloudflared/tunnel-credentials.json";
      default = "http_status:404";
      ingress = {
        "*.${domain}" = "http://localhost:80"; # hand straight to Caddy
      };
    };
  };

=======
  # ---- Caddy [obviously native] ----
  # The original stack used the caddy-docker-proxy plugin to auto-generate routes
  # from container labels. Going native means writing the routes explicitly - more
  # verbose, but it's one file instead of scattered labels, and it's easier to audit.
>>>>>>> Stashed changes
=======
>>>>>>> 27d0484 (chore(nixos): rm cloudflared from native services)
  services.caddy = {
    enable = true;
    extraConfig = ''
      (tinyauth_forwarder) {
        forward_auth 127.0.0.1:3000 {
          uri /api/auth/caddy
          copy_headers Remote-User Remote-Name Remote-Email Remote-Groups
          header_up X-Forwarded-Proto https
        }
      }
    '';
    virtualHosts = {
      # Unprotected internal/core services
      "id.${domain}".extraConfig        = "reverse_proxy 127.0.0.1:1411";
      "auth.${domain}".extraConfig      = "reverse_proxy 127.0.0.1:3000";
      "jellyfin.${domain}".extraConfig  = "reverse_proxy 127.0.0.1:8096";
      "music.${domain}".extraConfig     = "reverse_proxy 127.0.0.1:4533";
      "arcane.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:3552";

      # Protected by TinyAuth SSO
      "deemix.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:6595";
      "slskd.${domain}".extraConfig     = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:5030";
      "sonarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8989";
      "radarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:7878";
      "lidarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8686";
      "bazarr.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:6767";
      "prowlarr.${domain}".extraConfig  = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:9696";
      "seerr.${domain}".extraConfig     = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:5055";
      "qbit.${domain}".extraConfig      = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8080";
      "archive.${domain}".extraConfig   = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:8000";
      "aurral.${domain}".extraConfig    = "import tinyauth_forwarder\nreverse_proxy 127.0.0.1:3001";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
