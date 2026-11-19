#!/usr/bin/env bash
set -euo pipefail
control="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="${BUILD_ROOT:-/workspace}"
source_dir="$root/android"
logs="$root/logs"
export HOME="$root/home"
export CCACHE_DIR="$root/ccache" USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache
export BUILD_JOBS="${BUILD_JOBS:-28}" KERNEL_JOBS="${KERNEL_JOBS:-28}"
export GOMEMLIMIT=80GiB GOGC=100 GOMAXPROCS="$BUILD_JOBS"
export BUILD_USERNAME=BasicOS2025 BUILD_HOSTNAME=gcp-s8
export ALLOW_MISSING_DEPENDENCIES=false
mkdir -p "$HOME" "$source_dir" "$logs" "$root/results"
exec > >(tee -a "$logs/session.log") 2>&1
trap 'result=$?; date -u > "$logs/last-exit-time.txt"; echo "$result" > "$logs/last-exit-code.txt"' EXIT
cd "$source_dir"
git config --global user.name BasicOS2025
git config --global user.email 215494682+BasicOS2025@users.noreply.github.com
git config --global gc.auto 0
ccache -M 20G
if [[ ! -d .repo ]]; then
  repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --depth=1 --partial-clone --clone-filter=blob:limit=10M --git-lfs --no-clone-bundle
fi
mkdir -p .repo/local_manifests
cp "$control/manifests/dreamlte.xml" .repo/local_manifests/
if [[ ! -f "$root/source-sync-complete" ]]; then
  synced=false
  for retry in 1 2 3; do
    if repo sync -c -j8 --no-clone-bundle --no-tags --fail-fast 2>&1 | tee -a "$logs/sync.log"; then synced=true; break; fi
    sleep 15
  done
  [[ "$synced" == true ]]
  touch "$root/source-sync-complete"
fi
repo manifest -r -o "$logs/resolved-manifest.xml"
for attempt in $(seq 1 50); do
  python3 "$control/ci/apply-port.py" "$source_dir"
  git -C "$control" rev-parse HEAD > "$logs/control-commit.txt"
  git -C build/soong diff --binary > "$logs/applied-soong.patch"
  df -h "$root" > "$logs/disk-latest.txt"
  free -h > "$logs/memory-latest.txt"
  echo "Building dreamlte, attempt $attempt, jobs=$BUILD_JOBS"
  set +e
  (
    set -e
    bash "$control/ci/build-kernel.sh" "$source_dir" "$logs"
    set +u
    source build/envsetup.sh
    source vendor/lineage/vars/aosp_target_release
    lunch "lineage_dreamlte-${aosp_target_release}-userdebug"
    m -j"$BUILD_JOBS" bacon
  ) 2>&1 | tee "$logs/dreamlte-attempt-${attempt}.log"
  result=${PIPESTATUS[0]}
  set -e
  if [[ "$result" == 0 ]]; then
    python3 "$control/ci/collect.py" "$source_dir/out/target/product/dreamlte" "$root/results"
    cp "$logs/resolved-manifest.xml" "$logs/control-commit.txt" "$root/results/"
    echo SUCCESS > "$root/build-status"
    ccache -s
    exit 0
  fi
  echo "WAITING_FOR_FIX exit=$result attempt=$attempt" | tee "$root/build-status"
  tail -n 100 "$logs/dreamlte-attempt-${attempt}.log" > "$logs/latest-error.txt"
  revision=$(git -C "$control" rev-parse HEAD)
  changed=false
  for poll in $(seq 1 90); do
    sleep 30
    if git -C "$control" fetch origin main --depth=50 && [[ $(git -C "$control" rev-parse FETCH_HEAD) != "$revision" ]]; then
      git -C "$control" merge --ff-only FETCH_HEAD
      changed=true
      break
    fi
  done
  if [[ "$changed" != true ]]; then echo FIX_WAIT_EXPIRED > "$root/build-status"; exit "$result"; fi
done
