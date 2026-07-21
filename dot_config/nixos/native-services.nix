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
  systemd.services.navidrome.serviceConfig.EnvironmentFile = "/run/secrets/navidrome.env";
  # navidrome.env should contain:
  #   ND_LASTFM_APIKEY=...
  #   ND_LASTFM_SECRET=...

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

  # ---- recyclarr [VERIFIED] ----
  services.recyclarr = {
    enable = true;
    # Point at your existing chezmoi-managed configs/radarr.yml + sonarr.yml,
    # or convert to configuration = { ... } as a Nix attrset instead.
    configFile = /etc/nixos/media-stack/recyclarr.yml;
  };

  # ---- jellyseerr [VERIFIED] ----
  # Careful: the compose file used "seerr" (ghcr.io/seerr-team/seerr), a different
  # fork from jellyseerr. jellyseerr is the one with a nixpkgs module; seerr is not
  # packaged. Decide if jellyseerr is an acceptable substitute or keep seerr as a
  # container (see containers.nix).
  services.jellyseerr = {
    enable = true;
    port = 5055;
    openFirewall = false;
  };

  # ---- postgres + redis for audiomuse-ai [obviously native, no doubt here] ----
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "audiomusedb" ];
    ensureUsers = [{
      name = "audiomuse";
      ensureDBOwnership = true;
    }];
  };
  # password for the audiomuse role still needs to be set once via:
  #   sudo -u postgres psql -c "ALTER ROLE audiomuse WITH PASSWORD '...';"
  # (ensureUsers doesn't set passwords - pull from vault/secrets manager)

  services.redis.servers.audiomuse = {
    enable = true;
    port = 6380;
    bind = "127.0.0.1";
  };

  # ---- minecraft [ASSUMED, module exists] ----
  # The compose file uses itzg/minecraft-server with TYPE=PAPER and auto-downloads
  # the jar. The native module wants an actual pkgs derivation for the server -
  # nixpkgs doesn't reliably track bleeding-edge PaperMC builds. Since this was
  # already behind `profiles: ["extras"]` (i.e. optional), recommend leaving it as
  # a container rather than fighting the native module for marginal benefit.
  # See containers.nix.

  # ---- cloudflared [VERIFIED: services.cloudflared exists] ----
  services.cloudflared = {
    enable = true;
    tunnels."d088e974-c28b-419c-be94-148215f30b69" = {
      credentialsFile = "/run/secrets/cloudflare-tunnel.json";
      default = "http_status:404";
      ingress = {
        "*.${domain}" = "http://localhost:80"; # hand straight to Caddy
      };
    };
  };

  # ---- Caddy [obviously native] ----
  # The original stack used the caddy-docker-proxy plugin to auto-generate routes
  # from container labels. Going native means writing the routes explicitly - more
  # verbose, but it's one file instead of scattered labels, and it's easier to audit.
  services.caddy = {
    enable = true;
    virtualHosts = {
      "jellyfin.${domain}".extraConfig  = "reverse_proxy 127.0.0.1:8096";
      "music.${domain}".extraConfig     = "reverse_proxy 127.0.0.1:4533";
      "sonarr.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:8989";
      "radarr.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:7878";
      "lidarr.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:8686";
      "bazarr.${domain}".extraConfig    = "reverse_proxy 127.0.0.1:6767";
      "prowlarr.${domain}".extraConfig  = "reverse_proxy 127.0.0.1:9696";
      "seerr.${domain}".extraConfig     = "reverse_proxy 127.0.0.1:5055";
      "qbit.${domain}".extraConfig      = "reverse_proxy 127.0.0.1:8080";
      # remaining hosts (auth, id, deemix, slskd, archive, aurral, arcane, lrclib)
      # point at container ports - see containers.nix for those port numbers.
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
