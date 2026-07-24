#!/usr/bin/env bash

# radarr.yml hash: {{ include "dot_config/recyclarr/configs/radarr.yml" | sha256sum }}
# sonarr.yml hash: {{ include "dot_config/recyclarr/configs/sonarr.yml" | sha256sum }}

echo "Syncing Recyclarr configs to /var/lib…"
sudo mkdir -p /var/lib/recyclarr/configs
sudo cp ~/.config/recyclarr/configs/*.yml /var/lib/recyclarr/configs/

echo "Restarting Recyclarr sync service…"
sudo systemctl restart recyclarr.service

echo "Recyclarr sync completed."
