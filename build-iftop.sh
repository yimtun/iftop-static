#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")" && pwd)
version=2025.02.1
work="$root/build"
src="$work/buildroot-$version"
case "${1:-both}" in
    arm64|aarch64) arches=(aarch64) ;;
    x86_64) arches=(x86_64) ;;
    both) arches=(aarch64 x86_64) ;;
    *) echo "Usage: $0 [arm64|x86_64|both]" >&2; exit 2 ;;
esac
mkdir -p "$work" "$root/dist"
if [[ ! -f "$src/Makefile" ]]; then
    archive="$work/buildroot-$version.tar.xz"
    curl -fL --retry 3 "https://buildroot.org/downloads/buildroot-$version.tar.xz" -o "$archive"
    tar -xJf "$archive" -C "$work"
fi

for arch in "${arches[@]}"; do
    out="$work/out-$arch"
    mkdir -p "$out"
    cat > "$out/iftop_defconfig" <<CONFIG
BR2_${arch}=y
BR2_TOOLCHAIN_BUILDROOT_MUSL=y
BR2_STATIC_LIBS=y
BR2_PACKAGE_IFTOP=y
CONFIG
    make -C "$src" O="$out" BR2_DEFCONFIG="$out/iftop_defconfig" defconfig
    make -C "$src" O="$out" iftop
    binary=$(find "$out/target" -type f -name iftop -perm /111 -print -quit)
    [[ -n "$binary" ]]
    case "$arch" in
        aarch64) machine=AArch64; name=arm64 ;;
        x86_64) machine='Advanced Micro Devices X86-64'; name=x86_64 ;;
    esac
    readelf -h "$binary" | grep -E "Machine: +${machine}$" >/dev/null
    segments=$(readelf -lW "$binary")
    dynamic=$(readelf -dW "$binary")
    if [[ "$segments" == *INTERP* || "$dynamic" == *'(NEEDED)'* ]]; then
        echo "Unexpected dynamic dependency in $binary" >&2
        exit 1
    fi
    install -m 755 "$binary" "$root/dist/iftop-linux-$name"
    file "$root/dist/iftop-linux-$name"
done
