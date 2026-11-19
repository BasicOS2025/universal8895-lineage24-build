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
