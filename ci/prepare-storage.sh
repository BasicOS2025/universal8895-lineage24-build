#!/usr/bin/env bash
# Build on compressed, disposable loop files; never format a host disk/partition.
set -euo pipefail
volume="$RUNNER_TEMP/rom-volume"
mkdir -p "$volume"
loops=()
allocate() {
  local directory="$1" reserve="$2" available bytes loop
  available=$(df -B1 --output=avail "$directory" | tail -n1)
  bytes=$(( available - reserve * 1024 * 1024 * 1024 ))
  if (( bytes < 8 * 1024 * 1024 * 1024 )); then return; fi
  sudo fallocate -l "$bytes" "$directory/lineage24-storage.img"
  loop=$(sudo losetup --find --show "$directory/lineage24-storage.img")
  loops+=("$loop")
}
allocate "$RUNNER_TEMP" 12
if [[ -d /mnt && $(stat -c %d /mnt) != $(stat -c %d "$RUNNER_TEMP") ]]; then
  allocate /mnt 4
fi
if (( ${#loops[@]} == 0 )); then echo '::error::Insufficient disposable runner storage'; exit 1; fi
sudo mkfs.btrfs -f -d single -m single "${loops[@]}"
sudo mount -o compress-force=zstd:3,noatime "${loops[0]}" "$volume"
sudo chown "$(id -u):$(id -g)" "$volume"
mkdir -p "$volume/android"
df -h "$volume" "$RUNNER_TEMP"
sudo btrfs filesystem usage "$volume"
