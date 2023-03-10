#!/usr/bin/env bash
#
# Copyright (C) 2022 Neebe3289 <neebexd@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Personal script for kranul compilation !!

# Path
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"
AnyKernelPath="${MainPath}/anykernel"

# Clone clang
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir ${ClangPath}
rm -rf ${ClangPath}/*
wget -q $(curl https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "ZyC-Clang.tar.gz"
tar -xf ZyC-Clang.tar.gz -C ${ClangPath} && rm -rf ZyC-Clang.tar.gz

# Toolchain setup
export PATH="${ClangPath}/bin:${PATH}"
export LD_LIBRARY_PATH="${ClangPath}/lib:${LD_LIBRARY_PATH}"
export KBUILD_COMPILER_STRING="$(${ClangPath}/bin/clang --version | head -n 1)"

# Enviromental variable
export TZ="Asia/Jakarta"
DEVICE_MODEL="Redmi Note 8 Pro"
DEVICE_CODENAME="begonia"
export DEVICE_DEFCONFIG="begonia_user_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_USER="Neebeツ"
export KBUILD_BUILD_HOST="WorkSpace"
export KERNEL_NAME="$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"
export SUBLEVEL="4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
export COMMIT_HEAD="$(git rev-parse --short HEAD)"
IMAGE="${MainPath}/out/arch/arm64/boot/Image.gz-dtb"
BUILD_LOG="${MainPath}/out/log-$(TZ=Asia/Jakarta date +'%H%M').txt"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
DATE="$(date +"%d.%m.%Y")"

# Function of telegram
git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram

TELEGRAM="${MainPath}/Telegram/telegram"
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

tgf() {
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
}

# Function for uploaded kernel file
function push() {
    tgm "<i>Start to uploaded kernel file</i>"
    cd ${AnyKernelPath}
    ZIP=$(echo *.zip)
    RESPONSE="$(curl -# -F "name=${ZIP}" -F "file=@${ZIP}" -u :"${PD_API}" https://pixeldrain.com/api/file)"
    FILEID="$(echo "${RESPONSE}" | grep -Po '(?<="id":")[^"]*')"
    tgf "$BUILD_LOG"
    tgf "$ZIP" "✅ Compile took in $(($DIFF / 60)) Minutes and $(($DIFF % 60)) Seconds for ${DEVICE_CODENAME}"
    tgm "<b>Mirror Download Link :</b> https://pixeldrain.com/u/$FILEID"
}

# Send info build to telegram channel
tgm "
<b>===========================================</b>
<b>• DATE :</b> <code>$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")</code>
<b>• DEVICE :</b> <code>${DEVICE_MODEL} ($DEVICE_CODENAME)</code>
<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>
<b>• LINUX VERSION :</b> <code>${SUBLEVEL}</code>
<b>• BRANCH NAME :</b> <code>${BRANCH}</code>
<b>• COMPILER :</b> <code>${KBUILD_COMPILER_STRING}</code>
<b>• LAST COMMIT :</b> <code>$(git log --pretty=format:'%s' -1)</code>
<b>===========================================</b>
"

# Start Compile
START=$(date +"%s")
tgm "⚙️ <i>Compilation has been started</i>"

compile(){
make O=out ARCH=arm64 $DEVICE_DEFCONFIG
make -j"$CORES" ARCH=arm64 O=out \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    READELF=llvm-readelf \
    OBJSIZE=llvm-size \
    STRIP=llvm-strip \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
    2>&1 | tee "${BUILD_LOG}"

   if [[ -f "$IMAGE" ]]; then
      tgm "<i>Compile Kernel for $DEVICE_CODENAME successfully</i>"
   else
      tgm "<i>Compile Kernel for $DEVICE_CODENAME failed, Check build log to fix it !!</i>"
      tgf "$BUILD_LOG" "❌ Compile fail in $(($DIFF / 60)) Minutes and $(($DIFF % 60)) Seconds, Check build log to fix it !!"
      exit 1
   fi
      git clone --depth=1 https://github.com/Neebe3289/AnyKernel3 -b begonia-r-oss ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
}

# Function zipping environment
function zipping() {
    cd ${AnyKernelPath} || exit 1
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-${COMMIT_HEAD} by ${KBUILD_BUILD_USER}/g" anykernel.sh
    zip -r9 ${KERNEL_NAME}-${DEVICE_CODENAME}-${COMMIT_HEAD}-${DATE}.zip * -x .git README.md *placeholder
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push

