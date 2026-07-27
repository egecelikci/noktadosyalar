# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./backup.nix
    ./containers.nix
    ./hardware-configuration.nix
    ./services/caddy.nix
    ./services/auth.nix
    ./services/media.nix
    ./services/databases.nix
    # ./services/matrix.nix
    ./secrets.nix
    ./storage.nix
  ];

  boot = {
    # extraModprobeConfig = ''
    #   options nct6687d fan_control=1
    # '';
    # extraModulePackages = with config.boot.kernelPackages; [
    #   nct6687d
    # ];
    # kernelModules = [ "nct6687d" ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
  networking.hostName = "sunucu";
  networking.networkmanager.enable = true;

  networking.interfaces.enp42s0.ipv4.addresses = [
    {
      address = "192.168.1.20";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [
    "192.168.1.1"
    "1.1.1.1"
  ];

  time.timeZone = "Europe/Istanbul";

  virtualisation.docker.enable = true;

  users.users.egecelikci = {
    isNormalUser = true;
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaYomkrkg+WhBBuHrrPqCxqB2GRhqmLt5DJzQkjwalD"
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      # "video"
      # "render"
      # "uinput"
    ];
  };

  environment.systemPackages = with pkgs; [
    bitwarden-cli
    bws
    chezmoi
    git
    lm_sensors
    rclone
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "bws"
      # "steam"
      # "steam-original"
      # "steam-run"
      # "steam-unwrapped"
    ];

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
      };
    };
    coolercontrol.enable = true;
    fish.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.uinput.enable = true;

  # Merged Steam and Gamescope programs configuration
  # programs = {
  #   steam = {
  #     enable = true;
  #     remotePlay.openFirewall = true;
  #     gamescopeSession.enable = true;
  #   };
  #   gamescope = {
  #     enable = true;
  #     capSysNice = true;
  #   };
  # };

  services = {
    tailscale.enable = true;
    openssh.enable = true;
    # xserver.enable = false;
    # getty.autologinUser = "egecelikci";
    # greetd = {
    #   enable = true;
    #   settings = {
    #     default_session = {
    #       command = "env STEAM_CLIENT_IP=192.168.1.20 ${pkgs.gamescope}/bin/gamescope -W 1920 -H 1080 -f -e --xwayland-count 2 -- steam -pipewire-dmabuf -gamepadui";
    #       user = "egecelikci";
    #     };
    #   };
    # };
    # sunshine = {
    #   enable = true;
    #   autoStart = true;
    #   openFirewall = true;
    # };
  };

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "docker0" ];
    # extraCommands = ''
    #   iptables -A nixos-fw -p tcp -s 172.16.0.0/12 --dport 8008 -j nixos-fw-accept
    # '';
    allowedTCPPorts = [
      80
      443
      #   27036
      #   27037
      #   47990
      #   48010
      #   47984
      #   47989
    ];
    # allowedUDPPorts = [
    #   27031
    #   27036
    #   47998
    #   48000
    # ];
  };

  system.stateVersion = "26.05";
}
