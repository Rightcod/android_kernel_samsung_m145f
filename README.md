# Samsung Galaxy M14 4G Kernel (SM-M145F)

A custom Android GKI kernel source and build setup for the **Samsung Galaxy M14 4G (SM-M145F / A05S configuration)**.

This repository is a fork maintained for automated builds and includes KernelSU-Next with SuSFS support, Baseband Guard, NoMount, and AnyKernel3 packaging.

> **Warning:** Custom kernels may void warranty and can render a device unbootable. Make sure you understand Android boot, AVB, root, and recovery procedures before flashing. Always keep a recovery method and original boot image available.

## Features

- Qualcomm SM6225 / GKI kernel build configuration
- Samsung Galaxy M14 4G (`SM-M145F`) and `a05s` target setup
- KernelSU-Next with SuSFS
- Multi-manager support
- Baseband Guard integration
- NoMount integration
- Thin LTO builds
- `ccache` acceleration for faster repeated builds
- AVB-signed `boot.img` packaging
- Flashable AnyKernel3 ZIP generation
- GitHub Actions builds and releases

## Downloads

Prebuilt artifacts are available from the [Releases page](https://github.com/Rightcod/android_kernel_samsung_m145f/releases).

Typical release assets:

- `boot.img` — packaged and AVB-signed boot image
- `Image` — raw kernel image
- `AnyKernel3-M145F-A05S-*.zip` — flashable AnyKernel3 package
- `SHA256SUM.txt` — checksums for release verification

## Build Locally

### Requirements

A Debian/Ubuntu-based Linux environment is recommended. The script installs the toolchain when `kernel_platform/prebuilts` is absent.

Common packages used by the build:

```bash
sudo apt update
sudo apt install -y \
  bc bison build-essential ccache curl flex gcc git \
  libelf-dev libssl-dev lld llvm clang \
  python3 python3-pip rsync zip unzip dwarves pahole \
  device-tree-compiler libncurses-dev busybox cpio \
  libselinux1-dev openssl gawk p7zip-full
```

### Build

```bash
git clone --recurse-submodules https://github.com/Rightcod/android_kernel_samsung_m145f.git
cd android_kernel_samsung_m145f
chmod +x build.sh
./build.sh
```

Set `USE_CCACHE=0` to disable build caching:

```bash
USE_CCACHE=0 ./build.sh
```

The build script also initializes submodules and may download the build toolchain and KernelSU, SuSFS, BBG, or NoMount sources when they are not already present.

## Build Artifacts

The script creates the following files in the repository root:

| File | Description |
| --- | --- |
| `Image` | Raw compiled kernel image |
| `boot.img` | Packaged Samsung boot image |
| `AnyKernel3-M145F-A05S-<commit>.zip` | Flashable kernel package |
| `dist/` | Intermediate distribution files |
| `out/` | Kernel build output directory |

### Verify Downloads

```bash
sha256sum -c SHA256SUM.txt
```

## GitHub Actions Build

The repository includes an automated workflow at [`.github/workflows/build.yml`](https://github.com/Rightcod/android_kernel_samsung_m145f/blob/main/.github/workflows/build.yml).

It runs automatically on:

- pushes to `main`
- version tags matching `v*`
- pull requests
- manual workflow dispatch

To run manually:

1. Open **Actions** in GitHub.
2. Select **Build SM-M145F (Galaxy M14 4G) Kernel**.
3. Choose **Run workflow**.
4. Download artifacts or release files when the build completes.

## Flashing

Use the AnyKernel3 ZIP from the latest release with an unlocked bootloader and a compatible custom recovery.

Example (only from recovery's UI or an environment that already supports sideloading):

```text
Apply update / Install
Select the AnyKernel3-M145F-A05S-*.zip
Reboot to system
```

You may also flash `boot.img` using a compatible device-specific flashing procedure. Never install a boot image from an incompatible model or firmware line.

## Repository Layout

```text
.
├── build.sh                         # Main build and packaging script
├── anykernel/                       # AnyKernel3 flashable package template
├── ramdisk/                         # Samsung first-stage ramdisk
├── tools/                           # AVB signing and helper tools
├── vendor/                          # Vendor-related source or assets
├── kernel_platform/                 # GKI, Qualcomm, and kernel build platform
└── .github/workflows/build.yml      # Automated build and release workflow
```

## Upstream

Source repository: [subhu2008/android_kernel_samsung_m145f](https://github.com/subhu2008/android_kernel_samsung_m145f)

Maintained fork: [Rightcod/android_kernel_samsung_m145f](https://github.com/Rightcod/android_kernel_samsung_m145f)

## License

No repository-wide license is currently declared. Individual components may have their own licenses, including the AnyKernel3 files under [`anykernel/LICENSE`](https://github.com/Rightcod/android_kernel_samsung_m145f/blob/main/anykernel/LICENSE).

Review component licenses and upstream terms before redistribution or commercial use.
