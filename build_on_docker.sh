#!/usr/bin/env bash
# Copyright (C) 2018-2020 Rama Bondan Prakoso (rama982)
# Dokar Kernel Build Script

# ENV
export CHANNEL_ID=$1
export NEW_CAM=$2

if [ -z "$NEW_CAM" ] || [ -z "$CHANNEL_ID" ]; then
  echo 'one or more variable are undefined'
  exit 1
fi

# TELEGRAM START
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram
TELEGRAM=telegram/telegram

tg_channelcast() {
  "${TELEGRAM}" -c "${CHANNEL_ID}" -H \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

[[ "$2" == "new" ]] && CAM="New Cam" || CAM="Old Cam"

tg_fin() {
  "${TELEGRAM}" -f "$(echo "$ZIP_DIR"/*.zip)" \
  -c "${CHANNEL_ID}" -H \
      "$(echo "$CAM")"
}

tg_sendstick() {
  curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
      -d sticker="CAACAgUAAxkBAAJtPl63VVTJbNshKPOKo6rXCWaTisDgAAJbAAPs4JoeZr6bX1V3_TsZBA" \
      -d chat_id="$CHANNEL_ID"
}

# TELEGRAM END

# Main environtment
KERNEL_DIR=$(pwd)
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
DTBO_IMG=$KERNEL_DIR/out/arch/arm64/boot/dtbo.img

# Build kernel
export TZ="Asia/Jakarta"
export PATH="/root/tc/bin:$PATH"
export LD_LIBRARY_PATH="/root/tc/lib:$LD_LIBRARY_PATH"
CCV="$(clang --version | sed -n "1p" | perl -pe 's/\(http.*?\)//gs')"
if [ "$3" == "llvm" ]; then
  LDV="$(ld.lld --version | sed -n "1p" | perl -pe 's/\(\/.*?\) //gs')"
else
  LDV="$(ld --version | sed -n "1p" | perl -pe 's/\(\/.*?\) //gs')"
fi
export KBUILD_COMPILER_STRING="$CCV + $LDV"
export KBUILD_BUILD_USER="rama982"
export KBUILD_BUILD_HOST="circleci-docker"
KBUILD_BUILD_TIMESTAMP=$(date)
export KBUILD_BUILD_TIMESTAMP
if [ "$3" == "llvm" ]; then
  EXT=" AR=llvm-ar"
  EXT+=" NM=llvm-nm"
  EXT+=" OBJCOPY=llvm-objcopy"
  EXT+=" OBJDUMP=llvm-objdump"
  EXT+=" STRIP=llvm-strip"
  EXT+=" LD=ld.lld"
fi
build_clang () {
  make -j"$(nproc --all)" O=out \
                        ARCH=arm64 \
                        CC=clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-gnu- \
                        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                        $EXT
}

build_clang

if ! [ $? -eq 0 ]; then
  tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix!"
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
make -C "$ZIP_DIR" clean
wifi_modules
cp "$KERN_IMG" "$ZIP_DIR"
cp "$DTBO_IMG" "$ZIP_DIR"
make -C "$ZIP_DIR" normal

# Post TELEGRAM
CPU=$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) @ .*/\1/p')
KERNEL=$(cat out/include/config/kernel.release)
FILEPATH=$(echo "$ZIP_DIR"/*.zip)
HASH=$(git log --pretty=format:'%h' -1)
COMMIT=$(git log --pretty=format:'%h: %s' -1)
if [ -z "$3" ]; then
  tg_sendstick
  tg_channelcast "<b>Latest commit:</b> $COMMIT" \
                 "<b>Android:</b> 10 / Q" \
                 "<b>Kernel:</b> $KERNEL" \
                 "<b>Compiler:</b> $CCV" \
                 "<b>Linker:</b> $LDV" \
                 "<b>sha1sum:</b> <pre>$(sha1sum "$FILEPATH" | awk '{ print $1 }')</pre>" \
                 "<b>Date:</b> $KBUILD_BUILD_TIMESTAMP" \
                 "<b>Build Using:</b> $CPU"
fi
tg_fin
