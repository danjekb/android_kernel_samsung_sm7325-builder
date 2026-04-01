#!/bin/bash
##################################################
# Unofficial LineageOS Perf kernel Compile Script
# Based on the original compile script by vbajs
# Forked by Riaru Moda
##################################################

setup_environment() {
    echo "Setting up build environment..."
    # Imports
    local MAIN_DEFCONFIG_IMPORT="$1"
    local KERNELSU_SELECTOR="$2"
    # Maintainer info
    export KBUILD_BUILD_USER=isaiah-compile
    export KBUILD_BUILD_HOST=riaru.com
    export GIT_NAME="$KBUILD_BUILD_USER"
    export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"
    # GCC and Clang settings
    export CLANG_REPO_URI="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git"
    export GCC_64_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
    export GCC_32_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
    export CLANG_DIR=$PWD/clang
    export GCC64_DIR=$PWD/gcc64
    export GCC32_DIR=$PWD/gcc32
    export PATH="$CLANG_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
    # Defconfig Settings
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/$MAIN_DEFCONFIG_IMPORT"
    export COMPILE_MAIN_DEFCONFIG="vendor/$MAIN_DEFCONFIG_IMPORT"
    # KernelSU Settings
    if [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_BLXX" ]]; then
        export KSU_SETUP_URI="https://raw.githubusercontent.com/rsuntk/KernelSU/refs/heads/main/kernel/setup.sh"
        export KSU_BRANCH="main"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_NEXT" ]]; then
        export KSU_SETUP_URI="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh"
        export KSU_BRANCH="legacy"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=NONE" ]]; then
        export KSU_SETUP_URI=""
        export KSU_BRANCH=""
        export KSU_GENERAL_PATCH=""
    else
        echo "Invalid KernelSU selector. Use --ksu=KSU_BLXX, --ksu=KSU_NEXT, or --ksu=NONE."
        exit 1
    fi
    # KernelSU umount patch
    export KSU_UMOUNT_PATCH="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/64db0dfa2f8aa6c519dbf21eb65c9b89643cda3d.patch"
}

# Setup toolchain function
setup_toolchain() {
    echo "Setting up toolchain..."
    if [ ! -d "$PWD/clang" ]; then
        git clone $CLANG_REPO_URI --depth=1 clang &> /dev/null
    else
        echo "Local clang dir found, using it."
    fi
    if [ ! -d "$PWD/gcc64" ]; then
        git clone $GCC_64_REPO_URI --depth=1 gcc64 &> /dev/null
    else
        echo "Local gcc64 dir found, using it."
    fi
    if [ ! -d "$PWD/gcc32" ]; then
        git clone $GCC_32_REPO_URI --depth=1 gcc32 &> /dev/null
    else
        echo "Local gcc32 dir found, using it."
    fi
}

# Add patches function
add_patches() {
    # Set Makefile to be Warnings instead of Werror
    sed -i 's/-Werror=\([a-zA-Z0-9-]*\)/-W\1/g' Makefile
    # Enable CONFIG_SECTION_MISMATCH_WARN_ONLY to avoid build failure
    echo "CONFIG_SECTION_MISMATCH_WARN_ONLY=y" >> $MAIN_DEFCONFIG
    # Import sec_debug_summary_coreinfo.h
    sed -i '/include <linux\/sec_debug.h>/a #include <linux/samsung/debug/sec_debug_summary_coreinfo.h>' kernel/module.c
    # Apply general config patches
    echo "Tuning the rest of default configs..."
    sed -i 's/# CONFIG_PID_NS is not set/CONFIG_PID_NS=y/' $MAIN_DEFCONFIG
    echo "CONFIG_POSIX_MQUEUE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SYSVIPC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CGROUP_DEVICE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DEVTMPFS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_IPC_NS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DEVTMPFS_MOUNT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE_STATS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE_HISTOGRAM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_IOSCHED_BFQ=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    # Apply kernel rename to defconfig
    sed -i 's/CONFIG_LOCALVERSION="-perf"/CONFIG_LOCALVERSION="-perf-neon"/' $MAIN_DEFCONFIG
    # Apply O3 flags into Kernel Makefile
    sed -i 's/KBUILD_CFLAGS\s\++= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    sed -i 's/LDFLAGS\s\++= -O2/LDFLAGS += -O3/g' Makefile
}

# Add KernelSU function
add_ksu() {
    if [ -n "$KSU_SETUP_URI" ]; then
        echo "Setting up KernelSU..."
        if [[ "$KSU_SETUP_URI" == *"backslashxx/KernelSU"* ]]; then
            # Apply manual hook
            # disable for now, we're gonna use hookless mode
            # curl -LSs $KSU_GENERAL_PATCH | bash
            # Apply umount backport and kpatch fixes
            wget -qO- $KSU_UMOUNT_PATCH | patch -s -p1
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBE_EVENTS=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KRETPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        elif [[ "$KSU_SETUP_URI" == *"KernelSU-Next/KernelSU-Next"* ]]; then
            # Apply manual hook
            curl -LSs $KSU_GENERAL_PATCH | bash
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        fi
    else
        echo "No KernelSU to set up."
    fi
}

# Compile kernel function
compile_kernel() {
    # Do a git cleanup before compiling
    echo "Cleaning up git before compiling..."
    git config user.email $GIT_EMAIL
    git config user.name $GIT_NAME
    git config set advice.addEmbeddedRepo true
    git add .
    git commit -m "cleanup: applied patches before build" &> /dev/null
    # Start compilation
    echo "Starting kernel compilation..."
    make O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        $COMPILE_MAIN_DEFCONFIG
    yes "" | make O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        olddefconfig
    yes "" | make O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        syncconfig
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu-
}

# Main function
main() {
    # Check if all four arguments are valid
    echo "Validating input arguments..."
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <MAIN_DEFCONFIG_IMPORT> <KERNELSU_SELECTOR>"
        echo "Example: $0 lineage-a52sxq_defconfig --ksu=KSU_BLXX"
        exit 1
    fi
    if [ ! -f "arch/arm64/configs/vendor/$1" ]; then
        echo "Error: MAIN_DEFCONFIG_IMPORT '$1' does not exist."
        exit 1
    fi
    setup_environment "$1" "$2"
    setup_toolchain
    add_patches
    add_ksu
    compile_kernel
}

# Run the main function
main "$1" "$2"
