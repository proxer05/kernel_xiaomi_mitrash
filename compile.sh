#!/bin/sh

# Option on whether to upload the produced build to a file hosting service [Useful for CI builds]
UPLD=1
DEPS=0
if [ $UPLD = 1 ]; then
	UPLD_PROV="https://oshi.at"
    UPLD_PROV2="https://transfer.sh"
fi

if [ $DEPS = 1 ] && command -v apt &> /dev/null; then
    # Setup the build environment
    git clone --depth=1 https://github.com/akhilnarang/scripts environment
    cd environment && bash setup/android_build_env.sh && cd ..
else
    echo "apt is not present in your system"
    echo "The needed packages must be installed manually"
fi

# Clone toolchain from its repository
git clone --depth=1 https://github.com/kdrag0n/proton-clang clang

# Clone AnyKernel3
git clone --depth=1 -b citrus  https://gitlab.com/ganomin-dev/AnyKernel3.git AnyKernel3

# Export the PATH variable
export PATH="$(pwd)/clang/bin:$PATH"

# Clean up out
find out -delete
mkdir out

# Compile the kernel
build_clang() {
    make -j"$(nproc --all)" \
	O=out \
    ARCH=arm64 \
    CC=clang \
    CXX=clang++ \
    AR=llvm-ar \
    AS=llvm-as \
    NM=llvm-nm \
    LD=ld.lld \
    STRIP=llvm-strip \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    OBJSIZE=llvm-size \
    READELF=llvm-readelf \
	CROSS_COMPILE=aarch64-linux-gnu- \
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-

}

export ARCH=arm64
make O=out CC=clang vendor/lime-perf_defconfig
build_clang

# Zip up the kernel
zip_kernelimage() {
    rm -rf AnyKernel3/Image
    cp out/arch/arm64/boot/Image AnyKernel3
    rm -rf AnyKernel3/*.zip
    BUILD_TIME=$(date +"%d%m%Y-%H%M")
    cd AnyKernel3
    KERNEL_NAME=bsdkarnul-"${BUILD_TIME}"
    zip -r9 "$KERNEL_NAME".zip ./*
    cd ..
}

FILE="$(pwd)/out/arch/arm64/boot/Image"
if [ -f "$FILE" ]; then
    zip_kernelimage
    KERN_FINAL="$(pwd)/AnyKernel3/"$KERNEL_NAME".zip"
    echo "The kernel has successfully been compiled and can be found in $KERN_FINAL"
    if [ "$UPLD" = 1 ]; then
        for i in "$UPLD_PROV" "$UPLD_PROV2"; do
            curl --connect-timeout 5 -T "$KERN_FINAL" "$i"
            echo " "
        done
    fi
else
    echo "The kernel has failed to compile. Please check the terminal output for further details."
    exit 1
fi
