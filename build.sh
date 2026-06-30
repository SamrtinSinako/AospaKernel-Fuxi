#!/bin/bash
export ARCH=arm64
export SUBARCH=arm64
export TARGET_PRODUCT=fuxi

# Auto-update ReSukiSU to latest
if [ -d KernelSU/.git ]; then
    echo "[+] Updating ReSukiSU..."
    cd KernelSU
    git stash --quiet 2>/dev/null
    git pull --ff-only 2>/dev/null && echo "[-] Updated to latest" || echo "[-] Pull failed, using current version"
    cd ..
fi

# Auto-update Re:Kernel from myflavor/Re-Kernel
if [ -d Re-Kernel/.git ]; then
    echo "[+] Updating Re:Kernel..."
    cd Re-Kernel
    git stash --quiet 2>/dev/null
    git pull --ff-only 2>/dev/null && echo "[-] Updated to latest" || echo "[-] Pull failed, using current version"
    cd ..
fi
# Copy Re:Kernel LKM source to drivers/rekernel/
if [ -d Re-Kernel/LKM-Source ]; then
    echo "[+] Copying Re:Kernel LKM source to drivers/rekernel/..."
    cp -f Re-Kernel/LKM-Source/rekernel.c drivers/rekernel/
    cp -f Re-Kernel/LKM-Source/rekernel.h drivers/rekernel/
fi

MAKE_PARAMS="LLVM=1 LLVM_IAS=1 O=out LOCALVERSION=-By@Samrtin"

mkdir -p out
make $MAKE_PARAMS fuxi_defconfig -j$(nproc --all)
make $MAKE_PARAMS Image -j$(nproc --all) 2>&1 | tee out/build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "[!] Build failed. Check out/build.log for details."
    exit 1
fi

# Prepare AnyKernel3 flashable zip
rm -rf out/AnyKernel3
cp -r tools/AK3 out/

cp out/arch/arm64/boot/Image out/AnyKernel3/Image
cd out/AnyKernel3
ZIPNAME="AospaFuxi-resukisu-$(date -u '+%Y%m%d-%H%M').zip"
zip -r9 "$ZIPNAME" .
find . -not -name "*.zip" -not -name "." -exec rm -rf {} + 2>/dev/null
echo "[-] Zip created in: out/AnyKernel3/"
cp "$ZIPNAME" ~/
echo "[-] Also copied to: ~/$ZIPNAME"
