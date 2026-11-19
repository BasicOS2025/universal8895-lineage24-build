#!/usr/bin/env bash
set -euo pipefail
root="${BUILD_ROOT:-/mnt/android}"
control="$root/control"
mkdir -p "$root/logs" "$root/results"
exec > >(tee -a "$root/logs/host.log") 2>&1
sudo docker build -f "$control/ci/Dockerfile.cloud" -t s8-lineage24-build "$control/ci"
sudo docker image inspect s8-lineage24-build --format '{{.Id}}' > "$root/logs/container-image-id.txt"
set +e
sudo docker run --rm --name s8-lineage24-build --memory=110g --memory-swap=230g --shm-size=16g --ulimit nofile=1048576:1048576 \
    -v "$root:/workspace" -e BUILD_ROOT=/workspace -e BUILD_JOBS=16 -e KERNEL_JOBS=16 \
    s8-lineage24-build bash /workspace/control/ci/cloud-build.sh
result=$?
set -e
echo "$result" > "$root/logs/container-exit-code.txt"
# Preserve results on the boot disk before the VM is stopped and local SSDs vanish.
backup="$HOME/s8-results"
mkdir -p "$backup"
cp -a "$root/results/." "$backup/"
tar -C "$root" -czf "$backup/build-logs.tar.gz" logs
(cd "$backup" && sha256sum build-logs.tar.gz > LOG-SHA256SUMS)
sync
echo "Saved boot-disk backup to $backup; exit=$result. Download results before stopping VM."
exit "$result"
