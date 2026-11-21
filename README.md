# Experimental LineageOS 24 / Android 17 for Exynos 8895

Targets: Galaxy S8 SM-G950F (`dreamlte`), Galaxy S8+ SM-G955F (`dream2lte`),
and Galaxy Note8 SM-N950F (`greatlte`).

Each component is published in its own BasicOS2025 GitHub repository.
Device, common, hardware, kernel and vendor development branches are named
`lineage-24.0`. These are experimental migration branches, not verified releases.

The baseline is the user-provided universal8895 source on Codeberg: device/common
and kernel `lineage-23.2`, Samsung hardware and proprietary vendor `lineage-23.0`.
Original source-file license and copyright notices are retained.
Device/common/hardware repositories retain their source history. Kernel/vendor
initial imports are source snapshots with their exact upstream commits documented
in `PORTING.md` and the source inventory.

Initial changes make device input paths explicit, require the common/vendor board
configuration, and select legacy gralloc/ION platform paths. No successful Android
17 ROM build, recovery test, phone boot, or hardware validation is claimed.

Remaining work includes adapting the GCC 15.2 kernel build to the Android 17 build
integration, confirming
the custom Samsung HAL dependencies, and resolving additional IMS package sources.
The manifest records source selection; it is not a claim that the port builds.

The previous Exynos 7420 ROM run was cancelled. No Exynos 8895 ROM run has been
started by this initial repository publication.

## Kernel validation

KernelSU Next legacy is integrated with manual hooks and a pinned source revision.
All three device configs passed; complete S8 kernel Image builds with Next enabled
and KSU disabled both passed in Actions run 44379364933. Exact compatibility
backports from that successful build are committed. S8+/Note8 full kernel builds,
Android 17 ROM builds and phone boot/root testing remain outstanding.

https://github.com/BasicOS2025/android_kernel_samsung_universal8895/actions/runs/44379364933

## Boot packaging

The common tree now supplies uniquely named legacy Samsung DTBH packers instead
of passing unsupported --dt flags to modern mkbootimg. A host CI checks 70-DTB
tables, payload offsets, legacy header load addresses and SHA-1, and malformed
first-stage ramdisk rejection using the 8895 SYSTEM block path. This does not
replace a full ROM build or a physical boot test.

## Early-boot compatibility

The kernel accepts cpuset_v2_mode with the upstream v2-on-v1 behavior, rather
than rejecting Android 17's mount options. Common init uses noprefix cpuset
files and leaves controller mounts to libprocessgroup. Vendor cgroups select
legacy v1 memory/freezer and supported CPU controllers; unsupported schedtune
overrides are removed. Watchdogd is installed at its actual Android 17 path.

Source checks passed for all three defconfigs: required cgroup controllers,
XZ initramfs, ext4, seccomp, Binder devices and SELinux. Three-model Next-enabled
Image+DTB compilation is tracked in kernel Actions; source checks alone do not
validate boot. Raw kernel artifacts are not flashable boot/recovery images.

## GCP LineageOS 24 Android 17 builds

The GCP runner now syncs the all-device manifest and builds `dreamlte`,
`dream2lte`, and `greatlte` sequentially. The pinned Linux 4.4 kernel Image and
all three DTBs are built once and reused by the legacy Samsung boot packer for
each target. The persistent `/mnt/android/out` tree is reused; the build script
does not run a clean command. Each validated ROM and its checksum is saved to
`/home/taskinkose/s8-results` before the VM is stopped. This is a build and
archive validation, not a phone boot test.

## First Galaxy S8 ROM build

Dispatch `.github/workflows/build.yml` to build `lineage_dreamlte` userdebug with
no GApps. The S8-only manifest also pins the missing PhhIms source. Linux 4.4
is compiled from the pinned source with GCC 11, Next enabled, before the Android
build. Its Image and DTBs feed the legacy Samsung boot packer. This explicit
bridge avoids silently passing the kernel to Android 17's LLVM-only defaults.

A failed compile waits up to 45 minutes for a build-control update while retaining
all current objects, then retries in place. No clean command is used. This retains
progress within a live runner; a new Actions job does not restore the full Android
output tree. Ccache is restored and saved separately. Logs/manifests are uploaded
on failure; ROM artifacts are published only after ZIP/target/boot validation.
The first run is experimental and may expose further platform/HAL build errors.

## Runner storage

The first ROM run (44485226964) exhausted the runner disk during sync and the
runner could not upload logs or compiler cache. No compiler error was recorded.
Subsequent runs reclaim the unused tool cache, use shallow partial Git clones,
and build on a zstd-compressed Btrfs filesystem backed only by disposable loop
files. Free space on a separate /mnt filesystem is combined when available.
Host disk partitions are never formatted. A monitor reserves host/log space and
terminates the build cleanly before storage exhaustion kills the Actions agent.
Compression increases effective capacity but does not guarantee this free runner
has enough space for the complete Android 17 build. A terminated runner's full
source/output tree cannot be resumed; only a successfully saved cache survives.

The build-control patch `patches/soong-legacy-system-vendor.patch` keeps Make
image generation for Kati builds whose vendor path is system/vendor, provided
a Soong-defined system image is not selected. The experimental fsgen comparison
otherwise requests non-existent core variants of vendor-only health and STL
modules. Full Soong-only builds and separate vendor partitions retain the
original behavior. Actual Make packaging and its dependency checks remain active.
The patch is applied idempotently before each in-place retry.

## Memory pressure

The 16 GB runner reported repeated memory stalls before a SIGTERM (exit 143).
That signal alone does not identify whether storage protection, the runner or
another source terminated the process. New runs reserve 4 GB host-filesystem
swap before allocating the compressed volume, limit the Go analysis heap softly
to 10 GiB with more frequent collection, and compile Android and the legacy kernel with one job.
Memory, swap and process-exit diagnostics are retained alongside disk snapshots.
A new concurrency group allows recovery from a terminated process whose Actions
job has not yet finalized; running jobs are not cancelled by this change.

Single-job settings also cap Go parallelism at one. In-place retries export
NINJA_ARGS=-j1 after envsetup, covering a control shell that loaded an earlier
job count. Already-running processes cannot receive this setting retroactively.

## Dedicated GCP build host

`ci/cloud-host.sh` runs the pinned S8 build in an Ubuntu 22.04 container on the
Debian host. The persistent workspace defaults to /mnt/android, outside the small
boot disk. Cloud defaults are 16 build/kernel jobs, an 80 GiB soft Go heap limit
and 20 GiB ccache; GitHub defaults remain one job. Run under tmux so browser SSH
disconnection does not end compilation. Failures wait for control-repo fixes and
reuse objects. Results and compressed logs are copied to ~/s8-results on the boot
disk before the VM is stopped. Local SSD workspace is disposable; download the
verified ROM and logs before shutdown. This script does not stop the VM itself.

The cloud container permits 110 GiB RAM plus up to 120 GiB host swap when the
host supplies it. On the active VM the user requested a 120 GiB zstd zram device
with a 125 GiB physical-consumption cap; this cap does not preallocate RAM.
