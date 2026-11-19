#!/usr/bin/env bash
set -euo pipefail
logs="$RUNNER_TEMP/universal8895-logs"
volume="$RUNNER_TEMP/rom-volume"
mkdir -p "$logs"
setsid bash "$GITHUB_WORKSPACE/ci/build.sh" &
build_pid=$!
monitor() {
  while kill -0 "$build_pid" 2>/dev/null; do
    df -h "$volume" "$RUNNER_TEMP" > "$logs/disk-latest.txt"
    pool_free=$(df -B1 --output=avail "$volume" | tail -n1)
    host_free=$(df -B1 --output=avail "$RUNNER_TEMP" | tail -n1)
    if (( pool_free < 4*1024*1024*1024 || host_free < 2*1024*1024*1024 )); then
      echo '::error::Storage reserve reached; stopping cleanly before the Actions runner loses logs.' | tee "$logs/storage-error.txt"
      sudo btrfs filesystem usage "$volume" >> "$logs/disk-latest.txt"
      kill -TERM -- "-$build_pid" 2>/dev/null || true
      return
    fi
    sleep 20
  done
}
monitor &
monitor_pid=$!
trap 'kill "$monitor_pid" 2>/dev/null || true; kill -TERM -- "-$build_pid" 2>/dev/null || true' EXIT
set +e
wait "$build_pid"
result=$?
set -e
exit "$result"
