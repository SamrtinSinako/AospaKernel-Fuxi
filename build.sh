#!/bin/bash
export ARCH=arm64
export SUBARCH=arm64
export TARGET_PRODUCT=fuxi

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
    if ls Re-Kernel/LKM-Source/rekernel_x*.c 1>/dev/null 2>&1; then
        cp -f Re-Kernel/LKM-Source/rekernel_x*.c drivers/rekernel/
        cp -f Re-Kernel/LKM-Source/rekernel_x*.h drivers/rekernel/
        echo 'obj-$(CONFIG_REKERNEL) += rekernel_x.o' > drivers/rekernel/Makefile
        echo 'rekernel_x-y := rekernel_x_main.o rekernel_x_genl.o rekernel_x_netuid.o rekernel_x_frozen.o rekernel_x_binder.o rekernel_x_signal.o rekernel_x_netfilter.o rekernel_x_binder_kp.o' >> drivers/rekernel/Makefile
    else
        cp -f Re-Kernel/LKM-Source/rekernel.c drivers/rekernel/
        cp -f Re-Kernel/LKM-Source/rekernel.h drivers/rekernel/
        echo 'obj-$(CONFIG_REKERNEL) += rekernel.o' > drivers/rekernel/Makefile
    fi
fi

MAKE_PARAMS="LLVM=1 LLVM_IAS=1 O=out LOCALVERSION=-AOSPA-BY@Samrtin"

mkdir -p out
make $MAKE_PARAMS fuxi_defconfig -j$(nproc --all)
make $MAKE_PARAMS Image -j$(nproc --all) 2>&1 | tee out/build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "[!] Build failed. Check out/build.log for details."
    exit 1
fi

# ----- KernelPatch (FolkPatch) 自动打补丁 -----
KP_DIR="KernelPatch"
KP_RELEASE="0.13.1"
KP_BASE_URL="https://github.com/bmax121/KernelPatch/releases/download/${KP_RELEASE}"

mkdir -p ${KP_DIR}

# 下载 kptools-linux（主机工具，只需一次）
if [ ! -f "${KP_DIR}/kptools-linux" ]; then
    echo "[+] Downloading kptools-linux..."
    curl -L "${KP_BASE_URL}/kptools-linux" -o "${KP_DIR}/kptools-linux"
    chmod +x "${KP_DIR}/kptools-linux"
fi

# 自动获取最新 FolkPatch release 并提取 kpimg
FP_VERSION_FILE="${KP_DIR}/fp_version.txt"
echo "[+] Checking latest FolkPatch release..."
FP_LATEST=$(curl -sL https://api.github.com/repos/LyraVoid/FolkPatch/releases/latest 2>/dev/null | grep -oP '"tag_name":\s*"([^"]*)"' | cut -d'"' -f4)

if [ -z "$FP_LATEST" ]; then
    echo "[-] GitHub API rate limited, using cached kpimg if available"
    if [ ! -f "${KP_DIR}/kpimg-fp" ]; then
        echo "[!] No cached kpimg and cannot fetch latest release!"
        exit 1
    fi
else
    FP_CACHED=""
    [ -f "${FP_VERSION_FILE}" ] && FP_CACHED=$(cat "${FP_VERSION_FILE}")

    if [ "${FP_LATEST}" != "${FP_CACHED}" ] || [ ! -f "${KP_DIR}/kpimg-fp" ]; then
        echo "[+] New version detected: ${FP_LATEST} (cached: ${FP_CACHED:-none})"
        FP_APK_URL="https://github.com/LyraVoid/FolkPatch/releases/download/${FP_LATEST}/FolkPatch_*.apk"
        # GitHub redirects wildcard, need exact filename - use API to find it
        FP_DL_URL=$(curl -sL "https://api.github.com/repos/LyraVoid/FolkPatch/releases/tags/${FP_LATEST}" 2>/dev/null | grep -oP '"browser_download_url":\s*"[^"]*\.apk"' | cut -d'"' -f4 | head -1)
        if [ -z "$FP_DL_URL" ]; then
            echo "[!] Cannot find APK download URL for ${FP_LATEST}"
            exit 1
        fi
        echo "[+] Downloading ${FP_LATEST} APK to extract kpimg..."
        curl -L "${FP_DL_URL}" -o /tmp/fp.apk
        unzip -o /tmp/fp.apk assets/kpimg -d "${KP_DIR}/" >/dev/null 2>&1
        mv "${KP_DIR}/assets/kpimg" "${KP_DIR}/kpimg-fp"
        rm -rf "${KP_DIR}/assets"
        rm -f /tmp/fp.apk
        echo "${FP_LATEST}" > "${FP_VERSION_FILE}"
        echo "[-] kpimg extracted from FolkPatch ${FP_LATEST}"
    else
        echo "[-] FolkPatch ${FP_LATEST} already up to date"
    fi
fi

echo "[+] Applying FolkPatch (KernelPatch) to Image..."
./${KP_DIR}/kptools-linux \
    -p \
    -i out/arch/arm64/boot/Image \
    -S "qwerqwer4321" \
    -k ${KP_DIR}/kpimg-fp \
    -o out/arch/arm64/boot/Image

if [ $? -ne 0 ]; then
    echo "[!] KernelPatch failed. Check if Image is valid."
    exit 1
fi
echo "[-] KernelPatch applied successfully!"

# Prepare AnyKernel3 flashable zip
rm -rf out/AK3
cp -r tools/AK3 out/
cp out/arch/arm64/boot/Image out/AK3/Image
cd out/AK3
ZIPNAME="Fuxi-FolkPatch-$(date -u '+%Y%m%d-%H%M').zip"
zip -r9 "$ZIPNAME" .
find . -not -name "*.zip" -not -name "." -exec rm -rf {} + 2>/dev/null
echo "[-] Zip created in: out/AK3/"
cp "$ZIPNAME" ~/
echo "[-] Also copied to: ~/$ZIPNAME"