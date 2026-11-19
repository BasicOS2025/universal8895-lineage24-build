#!/usr/bin/env bash
set -euo pipefail
control="$GITHUB_WORKSPACE"
source_dir="$RUNNER_TEMP/rom-volume/android"
logs="$RUNNER_TEMP/universal8895-logs"
mkdir -p "$source_dir" "$logs" "$RUNNER_TEMP/universal8895-roms"
exec > >(tee -a "$logs/session.log") 2>&1
cd "$source_dir"
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --depth=1 --partial-clone --clone-filter=blob:limit=10M --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp "$control/manifests/dreamlte.xml" .repo/local_manifests/
# Emit progress while fetching; fail on a real sync error.
repo sync -c -j4 --no-clone-bundle --no-tags --fail-fast -v 2>&1 | tee "$logs/sync.log"
repo manifest -r -o "$logs/resolved-manifest.xml"
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache
ccache -M 4G
export BUILD_USERNAME=BasicOS2025 BUILD_HOSTNAME=github-actions
export ALLOW_MISSING_DEPENDENCIES=false
# Reduce Go analysis memory spikes on the free 16 GB runner.
export GOMEMLIMIT=10GiB GOGC=50 GOMAXPROCS=2
for attempt in $(seq 1 20); do
  python3 "$control/ci/apply-port.py" "$source_dir"
  set +e
  (
    set -e
    bash "$control/ci/build-kernel.sh" "$source_dir" "$logs"
    set +u
    source build/envsetup.sh
    source vendor/lineage/vars/aosp_target_release
    lunch "lineage_dreamlte-${aosp_target_release}-userdebug"
    m -j2 bacon
  ) 2>&1 | tee "$logs/dreamlte-attempt-${attempt}.log"
  result=${PIPESTATUS[0]}
  set -e
  if [[ "$result" == 0 ]]; then
    python3 "$control/ci/collect.py" "$source_dir/out/target/product/dreamlte" "$RUNNER_TEMP/universal8895-roms"
    ccache -s
    exit 0
  fi
  echo '::error::Build failed. Keeping all objects and waiting up to 45 minutes for an in-place fix.'
  tail -n 80 "$logs/dreamlte-attempt-${attempt}.log" >> "$GITHUB_STEP_SUMMARY"
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
  if [[ "$changed" != true || "$attempt" == 20 ]]; then exit "$result"; fi
done
