#!/usr/bin/env bash
#
# Copyright (C) 2018-2019 Rama Bondan Prakoso (rama982)
#
# Fedora Docker Kernel Build Script

# TELEGRAM START
export CHANNEL_ID="-1001299947067"

git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

TELEGRAM=telegram/telegram

tg_channelcast() {
    "${TELEGRAM}" -f $(echo "$ZIP_DIR"/*.zip) \
    -c "${CHANNEL_ID}" -H \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

tg_sendstick() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
        -d sticker="CAACAgUAAxkBAAJtPl63VVTJbNshKPOKo6rXCWaTisDgAAJbAAPs4JoeZr6bX1V3_TsZBA" \
        -d chat_id="$CHANNEL_ID"
}
# TELEGRAM END

# Main environtment
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG

#TC
#git clone --depth=1 https://github.com/crdroidmod/android_prebuilts_clang_host_linux-x86_clang-6607189 /root/aosp/clang && rm -rf /root/aosp/clang/.git
#git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 /root/aosp/gcc-arm64 && rm -rf /root/aosp/gcc-arm64/.git
#git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 /root/aosp/gcc-arm && rm -rf /root/aosp/gcc-arm/.git
#git clone --depth=1 https://github.com/trinket-devs/proton-clang /root/proton && rm -rf /root/proton/.git

# Build kernel
# export PATH="/root/aosp/clang/bin:/root/aosp/gcc-arm64/bin:/root/aosp/gcc-arm/bin:$PATH"
# export LD_LIBRARY_PATH="/root/aosp/clang/lib:/root/aosp/clang/lib64:$LD_LIBRARY_PATH"
export PATH="/root/nusantara/bin:$PATH"
export LD_LIBRARY_PATH="/root/nusantara/lib:$LD_LIBRARY_PATH"
export CCV="$(clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs')"
export LLDV="$(ld.lld --version | head -n1 | perl -pe 's/\((?:).*?\)//gs')"
export KBUILD_COMPILER_STRING="$CCV+ $LLDV"
export KBUILD_BUILD_USER="rama982"
export KBUILD_BUILD_HOST="circleci-docker"
export TZ="Asia/Jakarta"

KERNEL_CC="CC=clang "
KERNEL_CC+="AR=llvm-ar "
KERNEL_CC+="NM=llvm-nm "
KERNEL_CC+="OBJCOPY=llvm-objcopy "
KERNEL_CC+="OBJDUMP=llvm-objdump "
KERNEL_CC+="STRIP=llvm-strip "
KERNEL_CC+="LD=ld.lld "

build_clang () {
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-gnu- \
                          CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                          $KERNEL_CC
}

make O=out ARCH=arm64 "$CONFIG"
build_clang

if ! [ -a "$KERN_IMG" ]; then
    tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

# Make zip installer
git clone https://github.com/rama982/AnyKernel3

# ENV
ZIP_DIR=$KERNEL_DIR/AnyKernel3
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
STRIP="aarch64-linux-android-strip"

# Functions
wifi_modules () {
    # credit @adekmaulana
    for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
        "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
        "$KERNEL_DIR/scripts/sign-file" sha512 \
                "$KERNEL_DIR/out/signing_key.priv" \
                "$KERNEL_DIR/out/signing_key.x509" \
                "${MODULES}"
        case ${MODULES} in
                */wlan.ko)
            cp "${MODULES}" "${VENDOR_MODULEDIR}/qca_cld3_wlan.ko"
            ;;
        esac
    done
    echo -e "(i) Done moving wifi modules"
}

# Make zip
wifi_modules
cp "$KERN_IMG" "$ZIP_DIR"
make -C "$ZIP_DIR" normal

# Post TELEGRAM
if [[ $DEVICE =~ "ginkgo" ]]; then
    NAME="Redmi Note 8 / 8T"
fi

if ! [[ $BRANCH =~ "10" ]]; then
    ANDROID="Pie / 9"
else
    ANDROID="10 / Q"
fi

KERNEL=$(cat out/include/config/kernel.release)
FILEPATH=$(echo "$ZIP_DIR"/*.zip)
HASH=$(git log --pretty=format:'%h' -1)
COMMIT=$(git log --pretty=format:'%h: %s' -1)

tg_sendstick
tg_channelcast "<b>Latest commit:</b> <a href='https://github.com/Genom-Project/android_kernel_xiaomi_ginkgo/commits/$HASH'>$COMMIT</a>" \
               "<b>Device:</b> $NAME" \
               "<b>Android:</b> $ANDROID" \
               "<b>Kernel:</b> $KERNEL" \
               "<b>Toolchain:</b> $KBUILD_COMPILER_STRING" \
               "<b>sha1sum:</b> <pre>$(sha1sum $FILEPATH | awk '{ print $1 }')</pre>"
