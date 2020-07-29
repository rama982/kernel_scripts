#!/usr/bin/env bash
# Copyright (C) 2018-2019 Rama Bondan Prakoso (rama982)
# Dokar Kernel Build Script

# ENV
export CONFIG=$1
export DEVICE=$2
export CHANNEL_ID=$3

if [ -z "$CONFIG" ] || [ -z "$DEVICE" ] || [ -z "$CHANNEL_ID" ]; then
  echo 'one or more variable are undefined'
  exit 1
fi

# TELEGRAM START
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram
TELEGRAM=telegram/telegram

tg_channelcast() {
  "${TELEGRAM}" -f "$(echo "$ZIP_DIR"/*.zip)" \
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
#BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb

# Build kernel
export TZ="Asia/Jakarta"
export PATH="/root/sdclang/bin:$PATH"
export LD_LIBRARY_PATH="/root/sdclang/lib:$LD_LIBRARY_PATH"
if [ "$4" == "debian" ]; then
  CCV="$(clang --version | sed -n "1p" | cut -d \( -f 1"$CUT" | sed 's/[[:space:]]*$//')"
else
  CCV="$(clang --version | sed -n "2p" | cut -d \( -f 1"$CUT" | sed 's/[[:space:]]*$//')"
fi
LDV="$(ld --version | head -1)"
export KBUILD_COMPILER_STRING="$CCV + $LDV"
export KBUILD_BUILD_USER="rama982"
export KBUILD_BUILD_HOST="circleci-docker"
KBUILD_BUILD_TIMESTAMP=$(date)
export KBUILD_BUILD_TIMESTAMP

build_clang () {
  make -j"$(nproc --all)" O=out \
                        ARCH=arm64 \
                        CC=clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-gnu- \
                        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                        AR=llvm-ar \
                        NM=llvm-nm \
                        OBJCOPY=llvm-objcopy \
                        OBJDUMP=llvm-objdump \
                        STRIP=llvm-strip
}

make O=out ARCH=arm64 "$CONFIG"
build_clang

if ! [ -a "$KERN_IMG" ]; then
  tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
  exit 1
fi

# Make zip installer
git clone https://github.com/rama982/AnyKernel3

ZIP_DIR=$KERNEL_DIR/AnyKernel3
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
STRIP="aarch64-linux-gnu-strip"

wifi_modules () {
  # credit @adekmaulana
  for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
      "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
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
KERNEL=$(cat out/include/config/kernel.release)
FILEPATH=$(echo "$ZIP_DIR"/*.zip)
HASH=$(git log --pretty=format:'%h' -1)
COMMIT=$(git log --pretty=format:'%h: %s' -1)
tg_sendstick
tg_channelcast "<b>Latest commit:</b> <a href='https://github.com/Genom-Project/android_kernel_xiaomi_ginkgo/commits/$HASH'>$COMMIT</a>" \
               "<b>Android:</b> 10 / Q" \
               "<b>Kernel:</b> $KERNEL" \
               "<b>Compiler:</b> $CCV" \
               "<b>Linker:</b> $LDV" \
               "<b>sha1sum:</b> <pre>$(sha1sum "$FILEPATH" | awk '{ print $1 }')</pre>" \
               "<b>Date:</b> $KBUILD_BUILD_TIMESTAMP"
