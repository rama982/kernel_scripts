#!/usr/bin/env bash
# SemaphoreCI Kernel Build Script
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# Copyright (C) 2018 Rama Bondan Prakoso (rama982)
# SPDX-License-Identifier: GPL-3.0-or-later

#
# Telegram FUNCTION begin
#

git clone https://github.com/fabianonline/telegram.sh telegram

TELEGRAM_ID=-1001232319637
TELEGRAM=telegram/telegram
TELEGRAM_TOKEN=${BOT_API_KEY}

export TELEGRAM_TOKEN

# Push kernel installer to channel
function push() {
	JIP=$(echo Genom*.zip)
	curl -F document=@$JIP  "https://api.telegram.org/bot$BOT_API_KEY/sendDocument" \
			-F chat_id="$TELEGRAM_ID"
}

# Send the info up
function tg_channelcast() {
	"${TELEGRAM}" -c ${TELEGRAM_ID} -H \
		"$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)"
}

function tg_sendinfo() {
	curl -s "https://api.telegram.org/bot$BOT_API_KEY/sendMessage" \
		-d "parse_mode=markdown" \
		-d text="${1}" \
		-d chat_id="$TELEGRAM_ID" \
		-d "disable_web_page_preview=true"
}

# Errored prober
function finerr() {
	tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error...")"
	exit 1
}

# Send sticker
function tg_sendstick() {
	curl -s -X POST "https://api.telegram.org/bot$BOT_API_KEY/sendSticker" \
		-d sticker="CAADBQADgQADuMZ9GebdeJ3qOSmSAg" \
		-d chat_id="$TELEGRAM_ID" >> /dev/null
}

# Fin prober
function fin() {
	tg_sendinfo "$(echo "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
}

#
# Telegram FUNCTION end
#

# Main environtment
KERNEL_DIR=${HOME}/android_kernel_xiaomi_msm8953

KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb

ZIP_DIR_VINCE=$KERNEL_DIR/AnyKernel2-vince
CONFIG_VINCE=vince-perf_defconfig

ZIP_DIR_SAKURA=$KERNEL_DIR/AnyKernel2-sakura
CONFIG_SAKURA=sakura-perf_defconfig

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

CORES=$(grep -c ^processor /proc/cpuinfo)
THREAD="-j$CORES"
CROSS_COMPILE+="ccache "
CROSS_COMPILE+="$PWD/stock/bin/aarch64-linux-android-"

# Export
export JOBS="$(grep -c '^processor' /proc/cpuinfo)"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="ramakun"
export CROSS_COMPILE

# Install build package
install-package --update-new ccache bc bash git-core gnupg build-essential \
	zip curl make automake autogen autoconf autotools-dev libtool shtool python \
	m4 gcc libtool zlib1g-dev

# Clone toolchain
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 stock

# Clone AnyKernel2
git clone https://github.com/rama982/AnyKernel2 AnyKernel2-vince -b vince-aosp
git clone https://github.com/rama982/AnyKernel2 AnyKernel2-sakura -b sakura-aosp

# Build start
DATE=`date`
BUILD_START=$(date +"%s")

tg_sendstick

tg_channelcast "<b>GENOM CAF</b> kernel (for Custom ROM) new build!" \
		"Started on <code>$(hostname)</code>" \
		"For device <b>VINCE</b> (Redmi 5 Plus) & <b>SAKURA</b> (Redmi 6 Pro)" \
		"At branch <code>${BRANCH}</code>" \
		"Under commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>" \
		"Started on <code>$(date)</code>"

make O=out $CONFIG_VINCE $THREAD
make O=out $THREAD

if ! [ -a $KERN_IMG ]; then
	echo -e "Kernel compilation failed, See buildlog to fix errors"
	finerr
	exit 1
fi

cd $ZIP_DIR_VINCE
cp $KERN_IMG $ZIP_DIR_VINCE/zImage
make normal &>/dev/null
echo Genom*.zip
echo "Flashable zip generated under $ZIP_DIR."
cd ..

make O=out $CONFIG_SAKURA $THREAD
make O=out $THREAD

cd $ZIP_DIR_SAKURA
cp $KERN_IMG $ZIP_DIR_SAKURA/zImage
make normal &>/dev/null
echo Genom*.zip
echo "Flashable zip generated under $ZIP_DIR."
cd ..

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

cd $ZIP_DIR_VINCE
push
cd ..

cd $ZIP_DIR_SAKURA
push
cd ..

fin
# Build end