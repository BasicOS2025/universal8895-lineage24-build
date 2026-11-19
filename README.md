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
