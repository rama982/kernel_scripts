#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

#Directories
KERNEL_DIR=${HOME}/kernel_xiaomi_msm8953_vince
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
DTB=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-e7-non-treble.dtb
DTB_T=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-e7-treble.dtb
ZIP_DIR=$KERNEL_DIR/AnyKernel2

# Move to kernel directory
cd $KERNEL_DIR

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
KERNEL="Image"
DTBIMAGE="dtb"
DEFCONFIG="genom_defconfig"


## Always ARM64
ARCH=arm64

## Always use all threads
THREADS=2

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

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))

echo -e "${green}"
echo "-------------------"
echo "Build Completed in: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo "-------------------"
echo -e "${restore}"

echo

if ! [ -a $KERN_IMG ]; then
    echo -e "Kernel compilation failed, See buildlog to fix errors"
    exit 1
else
    cd $ZIP_DIR
    make clean &>/dev/null
    cp $KERN_IMG $ZIP_DIR/kernel/Image.gz
    cp $DTB_T $ZIP_DIR/treble/msm8953-qrd-sku3-e7-treble.dtb
    cp $DTB $ZIP_DIR/nontreble/msm8953-qrd-sku3-e7-non-treble.dtb
    make normal &>/dev/null
    echo Genom*.zip
    echo -e "$purple(i) Flashable zip generated under $ZIP_DIR."
    cd ..
fi

exit
# end
