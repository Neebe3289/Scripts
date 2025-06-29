#!/usr/bin/env bash
#
# Copyright (C) 2022-2025, Neebe3289 <neebexd@gmail.com>
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
# Inspired the script from Panchajanya1999 based.

set -e

if [ -z "${TELEGRAM_TOKEN}" ] || [ -z "${TELEGRAM_CHAT}" ]; then
      err "Missing Token or Chat api keys!.."
      exit 1
fi

# Function to show an informational message.
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

MAIN_DIR="$(pwd)"
DEVICE_MODEL="Redmi Note 8 Pro"
DEVICE_CODENAME="begonia"
DEVICE_DEFCONFIG="begonia_user_defconfig"
IMAGE="Image.gz-dtb"
KERNEL_NAME="perf-Kernel"
KERNEL_VER="$(make kernelversion)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT_HASH="$(git rev-parse --short HEAD)"
DATE="$(date +'%Y%m%d-%H%M')"
WITH_KSU="no" # 'no' | 'yes'
TOOLCHAIN="aosp" # 'aosp' | 'zyc'

# Clone function.
clone() {
       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
             msg "|| Downloading AOSP Clang ||"
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9" -b lineage-19.1 gcc64
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9" -b lineage-19.1 gcc32
             mkdir -p clang-llvm && aria2c -s16 -x16 -k1M "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r536225.tar.gz" -o clang.tar.gz
             tar -zxvf clang.tar.gz -C clang-llvm && rm -rf clang.tar.gz
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
             msg "|| Downloading ZyC Clang ||"
             mkdir -p clang-llvm && aria2c -s16 -x16 -k1M "https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250322-release/Clang-21.0.0git-20250322.tar.gz" -o zyc-clang.tar.gz
             tar -zxvf zyc-clang.tar.gz -C clang-llvm && rm -rf zyc-clang.tar.gz
             #cd clang-llvm && bash <(curl -s https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman) --patch=glibc
             #cd ..
       fi

       msg "|| Clone AnyKernel3 source ||"
       git clone --depth=1 "https://github.com/Neebe3289/AnyKernel3" -b begonia AK3
       msg "|| Clone telegram.sh source ||"
       git clone --depth=1 "https://github.com/fabianonline/telegram.sh" telegram
}

# Exports function.
exports() {
       export TZ="Asia/Jakarta"
       export ARCH="arm64"
       export DEVICE_DEFCONFIG
       export KBUILD_BUILD_USER="build-user"
       export KBUILD_BUILD_HOST="build-host"
       export CORES="$(nproc --all)"
       export CCACHE_DIR=/tmp/ccache
       export USE_CCACHE=1
       ccache -M10G -o compression=true -z
       export TELEGRAM="${MAIN_DIR}/telegram/telegram"

       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
             export PATH="${MAIN_DIR}/clang-llvm/bin:${MAIN_DIR}/gcc64/bin:${MAIN_DIR}/gcc32/bin:${PATH}"
             export LD_LIBRARY_PATH="${MAIN_DIR}/clang-llvm/lib:${LD_LIBRARY_PATH}"
             export KBUILD_COMPILER_STRING="$("${MAIN_DIR}/clang-llvm/bin/clang" --version | head -n 1)"
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
             export PATH="${MAIN_DIR}/clang-llvm/bin:${PATH}"
             export KBUILD_COMPILER_STRING="$("${MAIN_DIR}/clang-llvm/bin/clang" --version | head -n 1)"
       fi
}

# Function to show an informational message to telegram.
send_msg() {
    "${TELEGRAM}" -H -D \
    "$(
        for POST in "${@}"; do
            echo "${POST}"
        done
    )"
}

send_file() {
    "${TELEGRAM}" -H \
        -f "$1" \
        "$2"
}

# Function for KernelSU.
kernelsu() {
       if [[ "${WITH_KSU}" == "yes" ]]; then
             msg "|| Do make kernelsu functional ||"
             cd "${MAIN_DIR}"
             curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/refs/heads/next/kernel/setup.sh" | bash -s next
             curl -LSs https://github.com/Neebe3289/kernel_xiaomi_begonia/commit/9e75e4350a37560fc56b3a67f24874a2342739c7.patch | patch -p1
             curl -LSs https://github.com/Neebe3289/kernel_xiaomi_begonia/commit/130ac439d20de3c62600960c78f215627361cf63.patch | patch -p1
             curl -LSs https://github.com/Neebe3289/kernel_xiaomi_begonia/commit/dbe1d7d7668beef540bb4e5badd27a7dc7c99739.patch | patch -p1
             curl -LSs https://github.com/Neebe3289/kernel_xiaomi_begonia/commit/45d3fc4aedcf7e235047bf538a9920601c854cbb.patch | patch -p1
             curl -LSs https://github.com/Neebe3289/kernel_xiaomi_begonia/commit/52a95145b911b245616094844f4f8efca52b56b0.patch | patch -p1
             curl -LSs https://github.com/sidex15/android_kernel_lge_sm8150/commit/fcc59dc3310d3a1511d02dc3ac6d1e113517ece1.patch | patch -p1
             echo "CONFIG_KSU=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KSU_DEBUG=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KSU_KPROBES_HOOK=n" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KPROBES=n" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_TMPFS_XATTR=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
       fi
}

# Compilation setup.
compile() {
       # Send info build to telegram
       send_msg "<b>==========================================</b>" \
          "<b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>" \
          "<b>• DEVICE :</b> <code>${DEVICE_CODENAME}</code>" \
          "<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>" \
          "<b>• LINUX VERSION :</b> <code>${KERNEL_VER}</code>" \
          "<b>• BRANCH NAME :</b> <code>${BRANCH}</code>" \
          "<b>• COMPILER :</b> <code>${KBUILD_COMPILER_STRING}</code>" \
          "<b>• LAST COMMIT :</b> <code>$(git log --pretty=format:'%s' -1)</code>" \
          "<b>==========================================</b>"

       # Make arrays
       MAKE=()
       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
             MAKE+=(
                CC="ccache clang"
                LD=ld.lld
                AR=llvm-ar
                NM=llvm-nm
                LLVM=1
                LLVM_IAS=1
                OBJCOPY=llvm-objcopy
                OBJDUMP=llvm-objdump
                READELF=llvm-readelf
                STRIP=llvm-strip
                CLANG_TRIPLE=aarch64-linux-gnu-
                CROSS_COMPILE=aarch64-linux-android-
                CROSS_COMPILE_ARM32=arm-linux-androideabi-
            )
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
             MAKE+=(
                CC="ccache clang"
                LD=ld.lld
                AR=llvm-ar
                NM=llvm-nm
                LLVM=1
                LLVM_IAS=1
                OBJCOPY=llvm-objcopy
                OBJDUMP=llvm-objdump
                READELF=llvm-readelf
                STRIP=llvm-strip
                CROSS_COMPILE=aarch64-linux-gnu-
                CROSS_COMPILE_ARM32=arm-linux-gnueabi-
            )
       fi

       # Start build
       BUILD_START=$(date +"%s")
       kernelsu

       msg "|| Compilation has been started ||"
       mkdir -p out
       make O=out ARCH=arm64 "${DEVICE_DEFCONFIG}"
       make -j"${CORES}" O=out ARCH=arm64 "${MAKE[@]}" 2>&1 | tee error.log

       BUILD_END=$(date +"%s")
       TOTAL_TIME=$((BUILD_END - BUILD_START))

       if [[ -f "${MAIN_DIR}/out/arch/arm64/boot/${IMAGE}" ]]; then
             msg "|| Build succesfully to compile! ||"
             msg "Total time elapsed: $((TOTAL_TIME / 60)) minute(s), $((TOTAL_TIME % 60)) second(s)"
             # Zipping
             cp "${MAIN_DIR}/out/arch/arm64/boot/${IMAGE}" AK3
             cd AK3 || exit 1
             if [[ "${WITH_KSU}" == "yes" ]]; then
                   sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-KSU-${COMMIT_HASH} by ${KBUILD_BUILD_USER} @ github/g" anykernel.sh
                   ZIPNAME="${KERNEL_NAME}-KSU-${DEVICE_CODENAME}-${COMMIT_HASH}-${DATE}.zip"
             else
                   sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-${COMMIT_HASH} by ${KBUILD_BUILD_USER} @ github/g" anykernel.sh
                   ZIPNAME="${KERNEL_NAME}-${DEVICE_CODENAME}-${COMMIT_HASH}-${DATE}.zip"
             fi

             zip -r9 "${ZIPNAME}" ./* #-x .git .gitignore README.md ./*.zip#
             send_file "${ZIPNAME}" "✅ Build took : $((TOTAL_TIME / 60)) minute(s) and $((TOTAL_TIME % 60)) second(s) for ${DEVICE_CODENAME} | MD5 : <code>$(md5sum "${ZIPNAME}" | cut -d' ' -f1)</code>"
       else
             err "|| Build failed to compile! ||"
             ERROR_LOG="$(echo error.log)"
             send_file "${ERROR_LOG}" "❌ Build failed to compile, Please check log to fix it!"
             exit 1
       fi
}

clone
exports
compile
