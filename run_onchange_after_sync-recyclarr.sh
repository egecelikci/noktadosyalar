#!/usr/bin/env bash

# radarr.yml hash: {{ include "dot_config/recyclarr/configs/radarr.yml" | sha256sum }}
# sonarr.yml hash: {{ include "dot_config/recyclarr/configs/sonarr.yml" | sha256sum }}

echo "Syncing Recyclarr configs to /var/lib…"
sudo cp ~/.config/recyclarr/configs/*.yml /var/lib/recyclarr/configs/

echo "Restarting Recyclarr container…"
sudo systemctl restart docker-recyclarr

echo "Waiting for container to initialize…"
sleep 3

echo "Running Recyclarr sync…"
sudo docker exec -it recyclarr recyclarr sync
