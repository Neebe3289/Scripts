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

# Function to show an informational message.
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

if [ -z "${TELEGRAM_TOKEN}" ] || [ -z "${TELEGRAM_CHAT}" ]; then
    err "Missing Token or Chat api keys!.."
    exit 1
fi

MAIN_DIR="$(pwd)"
DEVICE_MODEL="Redmi Note 8 Pro"
DEVICE_CODENAME="begonia"
DEVICE_DEFCONFIG="begonia_user_defconfig"
KERNEL_NAME="perf-Kernel"
KERNEL_VER="$(make kernelversion)"
KERNEL_IMG="${MAIN_DIR}/out/arch/arm64/boot/Image.gz-dtb"
KERNEL_LOG="${MAIN_DIR}/out/buildlog-$(date +'%H%M').txt"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT_HASH="$(git log --pretty=format:'%h' -1)"
CORES="$(nproc --all)"
WITH_KSU="0" # '0' | '1'
TOOLCHAIN="aosp" # 'aosp' | 'zyc'

# Clone function.
clone() {
       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
             msg "|| Downloading AOSP Clang ||"
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9" -b lineage-19.1 gcc64
             git clone --depth=1 "https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9" -b lineage-19.1 gcc32
             mkdir -p clang-llvm && aria2c -s16 -x16 -k1M "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz" -o clang.tar.gz
             tar -zxvf clang.tar.gz -C clang-llvm && rm -rf clang.tar.gz
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
             msg "|| Downloading ZyC Clang ||"
             mkdir -p clang-llvm && aria2c -s16 -x16 -k1M "$(curl -s https://raw.githubusercontent.com/ZyCromerZ/Clang/refs/heads/main/Clang-main-link.txt)" -o zyc-clang.tar.gz
             tar -zxvf zyc-clang.tar.gz -C clang-llvm && rm -rf zyc-clang.tar.gz
       fi

       msg "|| Clone AnyKernel3 source ||"
       git clone --depth=1 "https://github.com/Neebe3289/AnyKernel3" -b begonia AK3
       msg "|| Clone telegram.sh source ||"
       git clone --depth=1 "https://github.com/fabianonline/telegram.sh" telegram
       msg "|| Clone patch source ||"
       git clone "https://github.com/Neebe3289/dumped" dump
}

# Exports function.
exports() {
       export TZ="Asia/Jakarta"
       export ARCH="arm64"
       export KBUILD_BUILD_USER="build-user"
       export KBUILD_BUILD_HOST="build-host"
       export KBUILD_COMPILER_STRING="$("${MAIN_DIR}"/clang-llvm/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
           export PATH="${MAIN_DIR}/clang-llvm/bin:${MAIN_DIR}/gcc64/bin:${MAIN_DIR}/gcc32/bin:${PATH}"
           if [[ -d "${MAIN_DIR}/clang-llvm/lib64" ]]; then
              export LD_LIBRARY_PATH="${MAIN_DIR}/clang-llvm/lib64:${LD_LIBRARY_PATH}"
           elif [[ -d "${MAIN_DIR}/clang-llvm/lib" ]]; then
              export LD_LIBRARY_PATH="${MAIN_DIR}/clang-llvm/lib:${LD_LIBRARY_PATH}"
           fi
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
           export PATH="${MAIN_DIR}/clang-llvm/bin:${PATH}"
           if [[ -d "${MAIN_DIR}/clang-llvm/lib64" ]]; then
              export LD_LIBRARY_PATH="${MAIN_DIR}/clang-llvm/lib64:${LD_LIBRARY_PATH}"
           elif [[ -d "${MAIN_DIR}/clang-llvm/lib" ]]; then
              export LD_LIBRARY_PATH="${MAIN_DIR}/clang-llvm/lib:${LD_LIBRARY_PATH}"
           fi
       fi
}

# Function to show an informational message to telegram.
TELEGRAM="${MAIN_DIR}/telegram/telegram"
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

tg_msg() {
    send_msg "<b>=====================================</b>" \
        "<b>• Date :</b> <code>$(date +'%A, %d %b %Y, %H:%M:%S')</code>" \
        "<b>• Device :</b> <code>${DEVICE_MODEL}</code>" \
        "<b>• Kernel Name :</b> <code>${KERNEL_NAME}</code>" \
        "<b>• Linux Version :</b> <code>${KERNEL_VER}</code>" \
        "<b>• Branch Name :</b> <code>${BRANCH}</code>" \
        "<b>• Compiler :</b> <code>${KBUILD_COMPILER_STRING}</code>" \
        "<b>• Last Commit :</b> <code>$(git log -1 --pretty=format:'%h : %s')</code>" \
        "<b>=====================================</b>"
}

# Function for KernelSU.
kernelsu() {
       if [[ "${WITH_KSU}" == "1" ]]; then
             msg "|| Do make kernelsu functional ||"
             cd "${MAIN_DIR}"
             curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/refs/heads/next/kernel/setup.sh" | bash -s next
             for ksu_patch in \
                 dump/KernelSU/kernel-add-TheWildJames-Fork-Manager.patch
             do
                 if patch -d KernelSU -p1 < "$ksu_patch"; then
                      msg "apply patch success for $ksu_patch"
                 else
                      err "apply patch failed for $ksu_patch"
                      exit 1
                 fi
             done
             for kpatch in \
                 dump/kernel_patches/cred-add-get-cred-rcu.patch \
                 dump/kernel_patches/fs-path_umount.patch \
                 dump/kernel_patches/maccess-rename-strncpy_from_unsafe_user-to-strncpy_from_user_nofault.patch \
                 dump/kernel_patches/integrate_scope-minimized_manual_hooks.patch \
                 dump/kernel_patches/0001-ptrace.patch
             do
                 if patch -p1 < "$kpatch"; then
                      msg "apply patch success for $kpatch"
                 else
                      err "apply patch failed for $kpatch"
                      exit 1
                 fi
             done
             echo "CONFIG_KSU=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KSU_DEBUG=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KSU_KPROBES_HOOK=n" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_KPROBES=n" >> arch/arm64/configs/$DEVICE_DEFCONFIG
             echo "CONFIG_TMPFS_XATTR=y" >> arch/arm64/configs/$DEVICE_DEFCONFIG
       fi
}

# Compilation setup.
compile() {
       # Make arrays
       MAKE=()
       if [[ "${TOOLCHAIN}" == "aosp" ]]; then
             MAKE+=(
                CC="ccache clang"
                LD=ld.lld
                LLVM=1
                LLVM_IAS=1
                CLANG_TRIPLE=aarch64-linux-gnu-
                CROSS_COMPILE=aarch64-linux-android-
                CROSS_COMPILE_ARM32=arm-linux-androideabi-
            )
       elif [[ "${TOOLCHAIN}" == "zyc" ]]; then
             MAKE+=(
                CC="ccache clang"
                LD=ld.lld
                LLVM=1
                LLVM_IAS=1
                CROSS_COMPILE=aarch64-linux-gnu-
                CROSS_COMPILE_ARM32=arm-linux-gnueabi-
            )
       fi

       # Start build
       BUILD_START="$(date +'%s')"
       msg "|| Compilation has been started ||"
       tg_msg

       mkdir -p out
       make O=out "${DEVICE_DEFCONFIG}"
       make -j"${CORES}" O=out "${MAKE[@]}" 2>&1 | tee "${KERNEL_LOG}"

       BUILD_END="$(date +'%s')"
       TOTAL_TIME="$((BUILD_END - BUILD_START))"
       DATE="$(date +'%Y%m%d-%H%M')"

       if [[ -f "${KERNEL_IMG}" ]]; then
             msg "|| Build succesfully to compile! ||"
             msg "Total time elapsed: $((TOTAL_TIME / 60)) minute(s), $((TOTAL_TIME % 60)) second(s)"
             # Zipping
             cp "${KERNEL_IMG}" AK3
             cd AK3 || exit 1
             if [[ "${WITH_KSU}" == "1" ]]; then
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
             send_file "${KERNEL_LOG}" "❌ Build failed to compile, Please check log to fix it!"
             exit 1
       fi
}

clone
exports
kernelsu
compile
