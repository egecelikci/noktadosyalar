{ config, pkgs, ... }:

{
  services.tinyauth = {
    enable = true;
    environmentFile = config.sops.secrets."tinyauth/env".path;
    settings = {
      APPURL = "https://auth.balcova.online";
      OAUTH_AUTOREDIRECT = "pocketid";
      OAUTH_PROVIDERS_POCKETID_AUTHURL = "https://id.balcova.online/authorize";
      OAUTH_PROVIDERS_POCKETID_TOKENURL = "http://127.0.0.1:1411/api/oidc/token";
      OAUTH_PROVIDERS_POCKETID_USERINFOURL = "http://127.0.0.1:1411/api/oidc/userinfo";
      OAUTH_PROVIDERS_POCKETID_REDIRECTURL = "https://auth.balcova.online/api/oauth/callback/pocketid";
      OAUTH_PROVIDERS_POCKETID_SCOPES = "openid email profile groups";
      OAUTH_PROVIDERS_POCKETID_NAME = "Pocket ID";
      APPS_SONARR_OAUTH_GROUPS = "admins";
      APPS_RADARR_OAUTH_GROUPS = "admins";
      APPS_LIDARR_OAUTH_GROUPS = "admins";
      APPS_BAZARR_OAUTH_GROUPS = "admins";
      APPS_PROWLARR_OAUTH_GROUPS = "admins";
      APPS_QBIT_OAUTH_GROUPS = "admins";
    };
  };

  services.pocket-id = {
    enable = true;
    environmentFile = config.sops.secrets."pocket-id/env".path;
    settings = {
      APP_URL = "https://id.balcova.online";
      TRUST_PROXY = true;
      HOST = "127.0.0.1";
      PORT = 1411;
    };
  };
}
