#!/usr/bin/env bash
set -euo pipefail
source_dir="$1"
logs="$2"
kernel="$source_dir/kernel/samsung/universal8895"
output="$source_dir/out/kernel-ci"
make -C "$kernel" O="$output" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- exynos8895-dreamlte_defconfig
make -C "$kernel" O="$output" -j1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC="ccache aarch64-linux-gnu-gcc" HOSTCC="ccache gcc" HOSTCFLAGS='-O2 -fcommon' Image dtbs 2>&1 | tee "$logs/kernel.log"
test -s "$output/arch/arm64/boot/Image"
test -s "$output/arch/arm64/boot/dts/exynos/exynos8895-dreamlte_eur_open_10.dtb"
cp "$output/.config" "$logs/kernel.config"
aarch64-linux-gnu-nm "$output/vmlinux" | grep -w kernelsu_init > "$logs/kernelsu-symbol.txt"
