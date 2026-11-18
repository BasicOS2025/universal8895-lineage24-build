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
integration, reviewing custom boot tools and duplicate host modules, confirming
the custom Samsung HAL dependencies, and resolving additional IMS package sources.
The manifest records source selection; it is not a claim that the port builds.

The previous Exynos 7420 ROM run was cancelled. No Exynos 8895 ROM run has been
started by this initial repository publication.
