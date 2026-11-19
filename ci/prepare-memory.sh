#!/usr/bin/env bash
set -euo pipefail
# A plain host-filesystem swap file avoids Btrfs CoW swap restrictions.
swapfile="$RUNNER_TEMP/lineage24.swap"
available=$(df -B1 --output=avail "$RUNNER_TEMP" | tail -n1)
if (( available < 20*1024*1024*1024 )); then
  echo '::error::Insufficient space to reserve swap and Actions diagnostics safely.'
  exit 1
fi
sudo fallocate -l 4G "$swapfile"
sudo chmod 600 "$swapfile"
sudo mkswap "$swapfile"
sudo swapon "$swapfile"
free -h
swapon --show
