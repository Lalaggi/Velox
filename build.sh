#!/bin/bash
set -e

cd "$(dirname "$0")"

ARCH=""
BUILD_NATIVE=false
BUILD_MESON=true

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --arch ARCH       Build for specific architecture: x86_64, aarch64, or both"
    echo "  --native          Build only for the current host architecture"
    echo "  --no-meson        Skip the local meson/ninja build and install"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --arch x86_64          Build Flatpak for x86_64 only"
    echo "  $0 --arch aarch64         Build Flatpak for aarch64 only"
    echo "  $0 --arch x86_64 --arch aarch64   Build Flatpak for both"
    echo "  $0 --native               Build Flatpak for current CPU only"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --native)
            BUILD_NATIVE=true
            shift
            ;;
        --no-meson)
            BUILD_MESON=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if ! $BUILD_NATIVE && [ -z "$ARCH" ]; then
    ARCH="x86_64"
    echo "No architecture specified, defaulting to x86_64"
fi

if $BUILD_NATIVE; then
    HOST_ARCH=$(uname -m)
    if [ "$HOST_ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$HOST_ARCH" = "aarch64" ]; then
        ARCH="aarch64"
    else
        echo "Unsupported host architecture: $HOST_ARCH"
        exit 1
    fi
    echo "Building for host architecture: $ARCH"
fi

if ! ls /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null; then
  echo "Installing qemu-user-static-binfmt for aarch64 cross-compilation..."
  paru -S --noconfirm qemu-user-static-binfmt
fi

build_flatpak_arch() {
    local arch=$1
    local build_dir="flatpak-build-${arch}"
    local repo_dir="flatpak-repo-${arch}"

    echo "=== Building Flatpak ${arch} bundle ==="
    if flatpak-builder --force-clean --user --install-deps-from=flathub --arch="${arch}" "${build_dir}" pkgs/flatpak/org.codeberg.el1lovescomputers.velox.json; then
      flatpak build-export "${repo_dir}" "${build_dir}"
      flatpak build-bundle "${repo_dir}" "flatpak-downloads/Velox-${arch}.flatpak" org.codeberg.el1lovescomputers.velox --arch="${arch}"
      rm -rf "${build_dir}" "${repo_dir}"
      echo "=== ${arch} bundle saved to flatpak-downloads/Velox-${arch}.flatpak ==="
    else
      echo "Skipping ${arch} build"
      rm -rf "${build_dir}" "${repo_dir}"
    fi
}

if [[ "$ARCH" == *"x86_64"* ]]; then
    build_flatpak_arch x86_64
fi

if [[ "$ARCH" == *"aarch64"* ]]; then
    build_flatpak_arch aarch64
fi

if $BUILD_MESON; then
    echo "=== Building and installing with ninja ==="
    meson setup build --buildtype=release --prefix=/usr
    ninja -C build
    sudo ninja -C build install || {
      echo "Install failed - try running manually: sudo ninja -C build install"
      exit 1
    }
fi

echo "=== Done ==="
echo "Flatpak bundles saved to flatpak-downloads/"
