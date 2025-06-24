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

# Function to show an informational message.
msg()
{
    echo -e "\e[1;32m$*\e[0m"
}

err()
{
    echo -e "\e[1;31m$*\e[0m"
}

# Check tg token|chat api keys.
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT" ]
then
      err "Missing Token or Chat api keys!.."
      exit 1
fi

#####################
# Basic Information #
#####################

# Set main directory of kernel source.
MAIN_DIR="$(pwd)"

# Specify name of device model.
# e.g: 'Redmi note 8 Pro'
DEVICE_MODEL="Redmi Note 8 Pro"

# Specify name of device codename.
# e.g: 'begonia'
DEVICE_CODENAME="begonia"

# Set device defconfig name.
# e.g: 'begonia_user_defconfig'
DEVICE_DEFCONFIG=begonia_user_defconfig

# Files/artifacts
IMAGE=Image.gz-dtb

# Specify kernel name.
KERNEL_NAME="perf-Kernel"

# Check kernel version.
KERNEL_VER=$(make kernelversion)

# Grab git current branch.
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Grab git commit hash.
COMMIT_HASH=$(git rev-parse --short HEAD)

# Set date/time into ZIP name.
DATE=$(TZ=Asia/Jakarta date +'%Y%m%d-%H%M')

# Specify command to use compiler.
# 'aosp' | 'zyc'
TOOLCHAIN=aosp

# Specify zipname.
ZIPNAME="${KERNEL_NAME}-${DEVICE_CODENAME}-${COMMIT_HASH}-${DATE}.zip"

# Clone function.
clone()
{
       if [ "${TOOLCHAIN}" = "aosp" ]
       then
             msg "|| Downloading AOSP Clang ||"
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9" -b lineage-19.1 gcc64
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9" -b lineage-19.1 gcc32
             mkdir clang-llvm && aria2c -s16 -x16 -k1M "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r536225.tar.gz" -o clang.tar.gz
             tar -zxvf clang.tar.gz -C clang-llvm && rm -rf clang.tar.gz
       elif [ "${TOOLCHAIN}" = "zyc" ]
       then
             msg "|| Downloading ZyC Clang ||"
             aria2c -s16 -x16 -k1M "https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250322-release/Clang-21.0.0git-20250322.tar.gz" -o zyc-clang.tar.gz
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
exports()
{
       # Timezone
       TZ=Asia/Jakarta
       
       # Specify architecture
       ARCH=arm64

       # Specify user name and host name
       KBUILD_BUILD_USER="neebe"
       KBUILD_BUILD_HOST="GithubCI"

       if [ "${TOOLCHAIN}" = "aosp" ]
       then
             PATH=${MAIN_DIR}/clang-llvm/bin:${MAIN_DIR}/gcc64/bin:${MAIN_DIR}/gcc32/bin:${PATH}
             LD_LIBRARY_PATH=${MAIN_DIR}/clang-llvm/lib:${LD_LIBRARY_PATH}
             KBUILD_COMPILER_STRING=$(${MAIN_DIR}/clang-llvm/bin/clang --version | head -n 1)
             COMPILER=${KBUILD_COMPILER_STRING}
       elif [ "${TOOLCHAIN}" = "zyc" ]
       then
             PATH=${MAIN_DIR}/clang-llvm/bin:${PATH}
             KBUILD_COMPILER_STRING=$(${MAIN_DIR}/clang-llvm/bin/clang --version | head -n 1)
             COMPILER=${KBUILD_COMPILER_STRING}
       fi
       # Specify CPU core/thread for compilation.
       # e.g: '2'/'4'/'8'/'12' or set default by using 'nproc --all'
       CORES=$(nproc --all)

       # Telegram directory.
       TELEGRAM=${MAIN_DIR}/telegram/telegram

       export TZ ARCH DEVICE_DEFCONFIG KBUILD_BUILD_USER KBUILD_BUILD_HOST \
              PATH KBUILD_COMPILER_STRING
}

# Function to show an informational message to telegram.
send_msg()
{
    "${TELEGRAM}" -H -D \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

send_file()
{
    "${TELEGRAM}" -H \
        -f "$1" \
        "$2"
}

# Compilation setup.
compile()
{
       # Send info build to telegram.
       send_msg "<b>===========================================</b>" \
          "<b>• DATE :</b> <code>$(date +"%A, %d %b %Y, %H:%M:%S")</code>" \
          "<b>• DEVICE :</b> <code>${DEVICE_CODENAME}</code>" \
          "<b>• KERNEL NAME :</b> <code>${KERNEL_NAME}</code>" \
          "<b>• LINUX VERSION :</b> <code>${KERNEL_VER}</code>" \
          "<b>• BRANCH NAME :</b> <code>${BRANCH}</code>" \
          "<b>• COMPILER :</b> <code>${COMPILER}</code>" \
          "<b>• LAST COMMIT :</b> <code>$(git log --pretty=format:'%s' -1)</code>" \
          "<b>===========================================</b>"

       # ARGS
       if [ "${TOOLCHAIN}" = "aosp" ]
       then
             MAKE+=(
                CC=clang \
                LD=ld.lld \
                AR=llvm-ar \
                NM=llvm-nm \
                LLVM=1 \
                LLVM_IAS=1 \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                READELF=llvm-readelf \
                STRIP=llvm-strip \
                CLANG_TRIPLE=aarch64-linux-gnu- \
                CROSS_COMPILE=aarch64-linux-android- \
                CROSS_COMPILE_ARM32=arm-linux-androideabi-
            )
       elif [ "${TOOLCHAIN}" = "zyc" ]
       then
             MAKE+=(
                CC=clang \
                LD=ld.lld \
                AR=llvm-ar \
                NM=llvm-nm \
                LLVM=1 \
                LLVM_IAS=1 \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                READELF=llvm-readelf \
                STRIP=llvm-strip \
                CROSS_COMPILE=aarch64-linux-gnu- \
                CROSS_COMPILE_ARM32=arm-linux-gnueabi-
            )
       fi
       
       # Compile time
       BUILD_START=$(date +"%s")

       msg "|| Compilation has been started ||"
       mkdir -p out
       make O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
       make -j"${CORES}" O=out ARCH=arm64 \
       "${MAKE[@]}" 2>&1 | tee error.log

       BUILD_END=$(date +"%s")
       TOTAL_TIME=$((BUILD_END - BUILD_START))

       if [ -f "${MAIN_DIR}/out/arch/arm64/boot/${IMAGE}" ]
       then
             msg "|| Build succesfully to compile! ||"
             msg "Total time elapsed: $((TOTAL_TIME / 60)) minute(s), $((TOTAL_TIME % 60)) second(s)"
             # Gen-zip
             cp ${MAIN_DIR}/out/arch/arm64/boot/${IMAGE} AK3
             cd AK3 || exit 1
             sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME}-${COMMIT_HASH} by ${KBUILD_BUILD_USER} @ github/g" anykernel.sh
             zip -r9 "${ZIPNAME}" ./* #-x .git .gitignore README.md ./*.zip#
             # Upload tg
             send_file "${ZIPNAME}" "✅ Build took : $((TOTAL_TIME / 60)) minute(s) and $((TOTAL_TIME % 60)) second(s) for ${DEVICE_CODENAME} | MD5 : <code>$(md5sum "${ZIPNAME}" | cut -d' ' -f1)</code>"
       else
             err "|| Build failed to compile! ||"
             ERROR_LOG=$(echo error.log)
             send_file "${ERROR_LOG}" "❌ Build failed to compile, Please check log to fix it!"
             exit 1
       fi
}

clone
exports
compile
