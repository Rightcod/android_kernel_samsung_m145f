#!/bin/bash

# Initialize git submodules
git submodule update --init --recursive || true

export WDIR="$(dirname $(readlink -f $0))" && cd "$WDIR"
export MERGE_CONFIG="${WDIR}/kernel_platform/common/scripts/kconfig/merge_config.sh"

# ccache - keep the cache outside of out/ so it survives clean builds and can
# be persisted by CI between runs.
export USE_CCACHE="${USE_CCACHE:-1}"
if [ "$USE_CCACHE" = "1" ]; then
    if ! command -v ccache >/dev/null 2>&1; then
        echo -e "[-] Error: ccache is not installed. Install it or set USE_CCACHE=0\n" >&2
        exit 1
    fi

    export CCACHE_DIR="${CCACHE_DIR:-${WDIR}/.ccache}"
    export CCACHE_BASEDIR="${CCACHE_BASEDIR:-${WDIR}}"
    export CCACHE_COMPILERCHECK="${CCACHE_COMPILERCHECK:-content}"
    export CCACHE_SLOPPINESS="${CCACHE_SLOPPINESS:-time_macros}"
    export CCACHE_COMPRESS="${CCACHE_COMPRESS:-true}"
    export CCACHE_COMPRESSLEVEL="${CCACHE_COMPRESSLEVEL:-6}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"
    # Keep ccache available inside the restricted hermetic toolchain PATH.
    export ADDITIONAL_HOST_TOOLS="${ADDITIONAL_HOST_TOOLS:-} ccache"

    mkdir -p "$CCACHE_DIR"
    ccache --max-size="$CCACHE_MAXSIZE" >/dev/null 2>&1 || true
    ccache -z >/dev/null 2>&1 || true
    trap 'ccache --show-stats || true' EXIT

    echo -e "[+] ccache enabled (dir: ${CCACHE_DIR}, max: ${CCACHE_MAXSIZE})\n"
fi

rm -rf "${WDIR}/dist" \
    && rm -rf "${WDIR}/out" \
    && mkdir -p "${WDIR}/dist"

# Download and install Toolchain
if [ ! -d "${WDIR}/kernel_platform/prebuilts" ]; then
    echo -e "[+] Downloading and installing Toolchain...\n"
    sudo apt install rsync p7zip-full -y
    curl -LO https://github.com/ravindu644/android_kernel_sm_x810/releases/download/toolchain/qcom-5.15-toolchain.tar.gz.zip
    curl -LO https://github.com/ravindu644/android_kernel_sm_x810/releases/download/toolchain/qcom-5.15-toolchain.tar.gz.z01
    7z x qcom-5.15-toolchain.tar.gz.zip && rm qcom-5.15-toolchain.tar.gz.zip qcom-5.15-toolchain.tar.gz.z01
    tar -xf qcom-5.15-toolchain.tar.gz && rm qcom-5.15-toolchain.tar.gz
    mv prebuilts "${WDIR}/kernel_platform" && chmod -R +x "${WDIR}/kernel_platform/prebuilts"    
fi

echo -e "[+] Toolchain installed...\n"

# Integrate KernelSU-Next (with SUSFS support)
cd kernel_platform/common

if [ ! -d "KernelSU-Next" ]; then
    curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
fi

# Multi-Manager support: authorize KSUN, BakaSU, official KernelSU, pershoot, debug, KOWX712
sed -i 's|0x3e6:79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7,0x338:f26471a28031130362bce7eebffb9a0b8afc3095f163ce0c75a309f03b644a1f|0x3e6:79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7,0x377:d3469712b6214462764a1d8d3e5cbe1d6819a0b629791b9f4101867821f1df64,0x337:7f833777a83dcf2d9c490a0eb4987b22c2a0d78310d7a048db49746b1076b4ef,0x338:f26471a28031130362bce7eebffb9a0b8afc3095f163ce0c75a309f03b644a1f,0x33b:c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6,0x375:484fcba6e6c43b1fb09700633bf2fb4758f13cb0b2f4457b80d075084b26c588|g' KernelSU-Next/kernel/Kbuild

cd ${WDIR}

# Integrate BBG

cd kernel_platform/common

if [ ! -d "Baseband-guard" ]; then
    wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
    sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' ${WDIR}/kernel_platform/common/security/Kconfig
fi

cd ${WDIR}

# Integrate Nomount
cd kernel_platform/common

if [ ! -d "NoMount" ]; then
    curl https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh | bash -
fi

cd ${WDIR}

#1. target config
export MODEL="a05s"
export PROJECT_NAME=${MODEL}
export REGION="eur"
export CARRIER="open"
export TARGET_BUILD_VARIANT="user"


#2. sm8550 common config
CHIPSET_NAME="sm6225"

export ANDROID_BUILD_TOP="${WDIR}"
export TARGET_PRODUCT=gki
export TARGET_BOARD_PLATFORM=gki

export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}

# for Lcd(techpack) driver build
export KBUILD_EXTRA_SYMBOLS="${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/mmrm-driver/Module.symvers"

# for Audio(techpack) driver build
export MODNAME=audio_dlkm

# Run menuconfig only if you want to.
# It's better to use MAKE_MENUCONFIG=0 when everything is already properly enabled, disabled, or configured.
export MAKE_MENUCONFIG=0

HERMETIC_VALUE=1
if [ "$MAKE_MENUCONFIG" = "1" ]; then
    HERMETIC_VALUE=0
fi

# Set commit hash
export COMMIT_HASH=$(git rev-parse --short HEAD)

# Localversion
export LOCALVERSION="-subhu2008-a05s-kernel-ds-${COMMIT_HASH}"

# custom build options
export GKI_BUILDSCRIPT="./kernel_platform/build/android/prepare_vendor.sh"
export BUILD_OPTIONS=(
    RECOMPILE_KERNEL=1
    SKIP_MRPROPER=1
    TRIM_NONLISTED_KMI=0
    KMI_ENFORCED=0
    HERMETIC_TOOLCHAIN=$HERMETIC_VALUE
    KMI_SYMBOL_LIST_STRICT_MODE=0
    BUILD_CHECK_FREEZED_ABI=0
    ABI_DEFINITION=""
    LTO="thin"
)

#3. build kernel
env ${BUILD_OPTIONS[@]} "${GKI_BUILDSCRIPT}" sec ${TARGET_PRODUCT} || exit 1

#4. Package kernel Image and boot.img with Samsung ramdisk and AVB footer
if [ -f "${OUT_DIR}/dist/Image" ]; then
    echo -e "[+] Kernel Image found at ${OUT_DIR}/dist/Image\n"
    mkdir -p "${WDIR}/dist"
    cp "${OUT_DIR}/dist/Image" "${WDIR}/dist/Image"
    cp "${OUT_DIR}/dist/Image" "${WDIR}/Image"
elif [ -f "${WDIR}/dist/Image" ]; then
    cp "${WDIR}/dist/Image" "${WDIR}/Image"
else
    echo -e "[-] Error: Image not found\n"
    exit 1
fi

echo -e "[+] Packaging boot.img with Samsung first-stage ramdisk and AVB signing...\n"

RAMDISK_PATH="${WDIR}/ramdisk/ramdisk.lz4"
MKBOOTIMG="${WDIR}/kernel_platform/tools/mkbootimg/mkbootimg.py"
AVBTOOL="${WDIR}/tools/avbtool"
AVBKEY="${WDIR}/tools/testkey_rsa4096.pem"

if [ ! -f "$MKBOOTIMG" ]; then
    MKBOOTIMG=$(command -v mkbootimg || echo "")
fi

if [ ! -f "$AVBTOOL" ]; then
    AVBTOOL=$(command -v avbtool || echo "")
fi

if [ ! -f "$AVBKEY" ] && [ -f "${WDIR}/kernel_platform/tools/mkbootimg/gki/testdata/testkey_rsa4096.pem" ]; then
    AVBKEY="${WDIR}/kernel_platform/tools/mkbootimg/gki/testdata/testkey_rsa4096.pem"
fi

if [ -f "$RAMDISK_PATH" ] && [ -n "$MKBOOTIMG" ]; then
    python3 "$MKBOOTIMG" \
        --header_version 4 \
        --kernel "${WDIR}/Image" \
        --ramdisk "$RAMDISK_PATH" \
        --pagesize 4096 \
        --os_version 13.0.0 \
        --os_patch_level 2025-08 \
        --output "${WDIR}/boot.img"

    if [ -n "$AVBTOOL" ] && [ -f "$AVBKEY" ]; then
        echo -e "[+] Signing boot.img with AVB footer (partition_size: 100663296)...\n"
        SALT=$(sha256sum "${WDIR}/Image" | cut -d " " -f 1)
        python3 "$AVBTOOL" add_hash_footer \
            --image "${WDIR}/boot.img" \
            --partition_size 100663296 \
            --partition_name boot \
            --key "$AVBKEY" \
            --algorithm SHA256_RSA4096 \
            --salt "$SALT"
    else
        echo -e "[!] Warning: AVB tool or key not found, skipping AVB signing\n"
    fi
elif [ -f "${OUT_DIR}/dist/boot.img" ]; then
    echo -e "[!] Warning: ramdisk or mkbootimg not found, falling back to raw GKI boot.img\n"
    cp "${OUT_DIR}/dist/boot.img" "${WDIR}/boot.img"
else
    echo -e "[-] Error: boot.img could not be built\n"
    exit 1
fi

#5. Package AnyKernel3 flashable zip
if [ -d "${WDIR}/anykernel" ] && command -v zip >/dev/null 2>&1; then
    echo -e "[+] Building AnyKernel3 flashable zip...\n"
    AK3_DIR="${WDIR}/out/anykernel_pkg"
    rm -rf "$AK3_DIR"
    mkdir -p "$AK3_DIR"
    cp -r "${WDIR}/anykernel/"* "$AK3_DIR/"
    cp "${WDIR}/Image" "$AK3_DIR/Image"
    AK3_ZIP="${WDIR}/AnyKernel3-M145F-A05S-${COMMIT_HASH}.zip"
    rm -f "$AK3_ZIP"
    (cd "$AK3_DIR" && zip -r9 "$AK3_ZIP" * -x "*.git*" "README.md" >/dev/null)
    rm -rf "$AK3_DIR"
    echo -e "[+] Created: ${AK3_ZIP}\n"
fi

echo -e "[+] Kernel build and packaging completed successfully\n"
exit 0
