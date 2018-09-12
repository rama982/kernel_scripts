#!/bin/bash
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# Copyright (C) 2018 Rama Bondan Prakoso (ramakun)
# SPDX-License-Identifier: GPL-3.0-or-later

# Install clang nightly prebuilt package and other depedencies
# This is for Ubuntu 14.04 LTS platform
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo apt-add-repository -s "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty main"
sudo apt-add-repository -s "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-6.0 main"
sudo apt-add-repository -s "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-7 main"
sudo apt-add-repository "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu trusty main"
sudo apt update
sudo apt-get install clang-8 lldb-8 lld-8 bc ccache gcc-aarch64-linux-gnu -y

#Directories
KERNEL_DIR=${HOME}/kernel_xiaomi_msm8953_vince
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
DTB=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-e7-non-treble.dtb
DTB_T=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-e7-treble.dtb
ZIP_DIR=$KERNEL_DIR/AnyKernel2

# Move to kernel directory
cd $KERNEL_DIR

# Clone AnyKernel2
git clone https://github.com/rama982/AnyKernel2

#
# Telegram FUNCTION begin
#

# Push to Channel
function push() {
    JIP=${ZIP_DIR}/$ZIP
    curl -F document=@"$JIP"  "https://api.telegram.org/bot$BOT_API_KEY/sendDocument" \
	 -F chat_id="-1001382306754"
}

# Send the info up
function tg_sendinfo() {
    curl -s "https://api.telegram.org/bot$BOT_API_KEY/sendMessage" \
         -d "parse_mode=markdown" \
         -d text="${1}" \
         -d chat_id="@genom_kernel_ch" \
         -d "disable_web_page_preview=true"
}

# Errored Prober
function finerr() {
    tg_sendinfo "$(echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds\nbut it's error...")"
    exit 1
}

# Send sticker
function tg_sendstick() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_API_KEY/sendSticker" \
         -d sticker="CAADBAADgQADCET1Hi9gCLqS45NBAg" \
         -d chat_id="-1001382306754" >> /dev/null
}


# Announce the completion
function tg_yay() {
    tg_sendinfo "$(echo "Compilation Completed")"
 }

# Fin Prober
function fin() {
     tg_sendinfo "$(echo "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
    tg_yay
}

#
# Telegram FUNCTION end
#

# READY

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# First-post works
keks="$(git rev-parse --abbrev-ref HEAD)"
tg_sendstick
tg_sendinfo "New build started on $(hostname) with CLANG at commit $(git log --pretty=format:'"%h : %s"' -1) in branch ${keks}"

# Resources
KERNEL="Image"
DTBIMAGE="dtb"
DEFCONFIG="genom_defconfig"


## Always ARM64
ARCH=arm64

## Always use all threads
THREADS=8

## clang specific values
CTRIPLE=aarch64-linux-gnu-

# Clang TC
CC=/usr/bin/clang-8

#Compiler string
KBUILD_COMPILER_STRING+="$(${CC} --version | head -n 1 | cut -d'-' -f1)"
KBUILD_COMPILER_STRING+=" ($(${CC} --version | head -n 1 | cut -d'-' -f2 | sed -e's/svn/trunk /g'))"
export KBUILD_COMPILER_STRING="$KBUILD_COMPILER_STRING"

# Unset CROSS_COMPILE and CCOMPILE if they're set
[[ ! -z ${CROSS_COMPILE} ]] && unset CROSS_COMPILE
[[ ! -z ${CCOMPILE} ]] && unset CCOMPILE

# Use ccache when available
if false; then
[[ $(which ccache > /dev/null 2>&1; echo $?) -eq 0 ]] && CCOMPILE+="ccache "
fi

# Whenever you're high enough to run this script
    CCOMPILE+=aarch64-linux-gnu-

# Functions

function make_kernel {
		echo
		make O=out $DEFCONFIG
		make O=out ARCH=${ARCH} CC="ccache ${CC}" CLANG_TRIPLE=${CTRIPLE} \
		CROSS_COMPILE="${CCOMPILE}" -j${THREADS}

}

# prepare and start build

DATE_START=$(date +"%s")


echo -e "${green}"
echo "-----------------"
echo "Making Kernel:"
echo "-----------------"
echo -e "${restore}"


# Vars
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=ramakun
export KBUILD_BUILD_HOST=semaphorebox

echo

echo

make_kernel

break

echo -e "${green}"
echo "-------------------"
echo "Build Completed in:"
echo "-------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo

if ! [ -a $KERN_IMG ]; then
    echo -e "Kernel compilation failed, See buildlog to fix errors"
    finerr
    exit 1
else
    cd $ZIP_DIR
    make clean &>/dev/null
    cp $KERN_IMG $ZIP_DIR/kernel/Image.gz
    cp $DTB_T $ZIP_DIR/treble/msm8953-qrd-sku3-e7-treble.dtb
    cp $DTB $ZIP_DIR/nontreble/msm8953-qrd-sku3-e7-non-treble.dtb
    make normal &>/dev/null
    cd ..
    echo -e "$purple(i) Flashable zip generated under $ZIP_DIR."
    NAME=Genom
    DATE=$(date "+%Y%m%d-%I%M")
    CODE=Pie-Kombo
    ZIP=${NAME}-${CODE}-${DATE}.zip
    echo "${ZIP_DIR}/$ZIP"
    push
    fin
fi

# end
