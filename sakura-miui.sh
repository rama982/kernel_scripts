#!/bin/bash

# Copyright (C) Abubakar Yagob (abubakaryagob@gmail.com)
# Copyright (C) Rama Bondan Prakoso (ramnarubp@gmail.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Color
green='\033[0;32m'

# Directories
KERNEL_DIR=$PWD
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
DTB_T=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3.dtb
ZIP_DIR=$KERNEL_DIR/AnyKernel2
CONFIG_DIR=$KERNEL_DIR/arch/arm64/configs

# Move to kernel directory
cd $KERNEL_DIR
git clone https://github.com/rama982/AnyKernel2 -b sakura-miui

# Exports
export ARCH=arm64
export SUBARCH=arm64
export PATH=/usr/lib/ccache:$PATH

# Misc
CONFIG=sakura_defconfig
CORES=$(grep -c ^processor /proc/cpuinfo)
THREAD="-j$CORES"

# Here We Go
echo -e "$green---------------------------------------------------------------------";
echo -e "---------------------------------------------------------------------\n";
echo -e "   _____ ______ _   _  ____  __  __   _  ________ _____  _   _ ______ _      ";
echo -e "  / ____|  ____| \ | |/ __ \|  \/  | | |/ /  ____|  __ \| \ | |  ____| |     ";
echo -e " | |  __| |__  |  \| | |  | | \  / | | ' /| |__  | |__) |  \| | |__  | |     ";
echo -e " | |__| | |____| |\  | |__| | |  | | | . \| |____| | \ \| |\  | |____| |____ ";
echo -e "  \_____|______|_| \_|\____/|_|  |_| |_|\_\______|_|  \_\_| \_|______|______|\n";
echo -e "---------------------------------------------------------------------";
echo -e "---------------------------------------------------------------------";

# Main script
while true; do
echo -e "\n$green[1] Build Sakura MIUI Kernel (with Google GCC)"
echo -e "[2] Regenerate defconfig"
echo -e "[3] Source cleanup"
echo -e "[4] Create flashable zip"
echo -e "$red[5] Quit$nc"
echo -ne "\n$brown(i) Please enter a choice[1-6]:$nc "

read choice

if [ "$choice" == "1" ]; then
echo -e "\n$green Cloning toolcahins if not exist..."
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 stock  
echo -e "\n$green building with Google GCC..."
CROSS_COMPILE+="ccache "
CROSS_COMPILE+="$PWD/stock/bin/aarch64-linux-android-"
export CROSS_COMPILE
make  O=out $CONFIG $THREAD
make  O=out $THREAD & pid=$!   

BUILD_START=$(date +"%s")
DATE=`date`
echo -e "\n$cyan#######################################################################$nc"
echo -e "$brown(i) Build started at $DATE using $CORES thread$nc"
  spin[0]="$blue-"
  spin[1]="\\"
  spin[2]="|"
  spin[3]="/$nc"
  echo -ne "\n$blue[Please wait...] ${spin[0]}$nc"
  while kill -0 $pid &>/dev/null
  do
    for i in "${spin[@]}"
    do
          echo -ne "\b$i"
          sleep 0.1
    done
  done

  if ! [ -a $KERN_IMG ]; then
    echo -e "\n$green(!) Kernel compilation failed, See buildlog to fix errors $nc"
    echo -e "$green#######################################################################$nc"
    exit 1
  fi

  $DTBTOOL -2 -o $KERNEL_DIR/arch/arm/boot/dt.img -s 2048 -p $KERNEL_DIR/scripts/dtc/ $KERNEL_DIR/arch/arm/boot/dts/ &>/dev/null &>/dev/null

  BUILD_END=$(date +"%s")
  DIFF=$(($BUILD_END - $BUILD_START))
  echo -e "\n$brown(i)Image-dtb compiled successfully.$nc"
  echo -e "$green#######################################################################$nc"
  echo -e "$green(i) Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nc"
  echo -e "$green#######################################################################$nc"
fi

if [ "$choice" == "2" ]; then
  echo -e "\n$cyan#######################################################################$nc"
  make O=out  $CONFIG savedefconfig
  cp out/.config arch/arm64/configs/sakura-full_defconfig
  cp out/defconfig arch/arm64/configs/$CONFIG
  echo -e "$purple(i) Defconfig generated.$nc"
  echo -e "$cyan#######################################################################$nc"
fi

if [ "$choice" == "3" ]; then
  echo -e "\n$cyan#######################################################################$nc"
  rm -f $DT_IMG
  make O=out clean &>/dev/null
  make mrproper &>/dev/null
  rm -rf out/*
  echo -e "$purple(i) Kernel source cleaned up.$nc"
  echo -e "$cyan#######################################################################$nc"
fi


if [ "$choice" == "4" ]; then
echo -e "\n$green#######################################################################$nc"
echo -e "\n$green Strip and move miui modules to AnyKernel2..."
# thanks to @adekmaulana
  cd $ZIP_DIR
  make clean &>/dev/null
  cd ..
  OUTDIR="$PWD/out/"
  SRCDIR="$PWD/"
  MODULEDIR="$PWD/AnyKernel2/modules/system/lib/modules/"
  PRIMA="$PWD/AnyKernel2/modules/system/vendor/lib/modules/wlan.ko"
  PRONTO="$PWD/AnyKernel2/modules/system/vendor/lib/modules/pronto/pronto_wlan.ko"

  STRIP="$PWD/stock/bin/$(echo "$(find "$PWD/stock/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
sed -e 's/gcc/strip/')"

  for MOD in $(find "${OUTDIR}" -name '*.ko') ; do
      "${STRIP}" --strip-unneeded --strip-debug "${MOD}" &> /dev/null
      "${SRCDIR}"/scripts/sign-file sha512 \
                                  "${OUTDIR}/signing_key.priv" \
                                  "${OUTDIR}/signing_key.x509" \
                                  "${MOD}"
      find "${OUTDIR}" -name '*.ko' -exec cp {} "${MODULEDIR}" \;
      case ${MOD} in

           */wlan.ko)
             cp -ar "${MOD}" "${PRIMA}"
             cp -ar "${MOD}" "${PRONTO}"

      esac
  done
  rm $PWD/AnyKernel2/modules/system/lib/modules/wlan.ko
  cd $ZIP_DIR
  cp $KERN_IMG $ZIP_DIR/kernel/Image.gz
  cp $DTB_T $ZIP_DIR/treble/msm8953-qrd-sku3-sakura.dtb
  make normal &>/dev/null
  cd ..
  echo -e "$green(i) Flashable zip generated under $ZIP_DIR.$nc"
  echo -e "$green#######################################################################$nc"
fi


if [ "$choice" == "5" ]; then
 exit 
fi
done
