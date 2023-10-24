#!/bin/bash
#set -e
# Clone kernel
export PWDIR=$(pwd)
echo -e "$green << cloning kernel >> \n $white"
git clone --depth=1 https://github.com/itsshashanksp/kernel_xiaomi_sm6150.git -b perf 13
cd 13
git submodule init
git submodule update

git submodule update --recursive --remote

rm -rf ZIPOUT

rm -rf out

git config --local user.name "kamlesh24299"
git config --local user.email "kamleshvansjalia02@gmail.com"

export KERNEL_DEFCONFIG=vendor/sweet_perf_defconfig
export date=$(date +"%Y-%m-%d-%H%M")
export ARCH=arm64
export SUBARCH=arm64
mkdir -p ZIPOUT

# Tool Chain
echo -e "$green << cloning gcc from arter >> \n $white"
git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 "$PWDIR"/../gcc64
git clone --depth=1 https://github.com/mvaisakh/gcc-arm "$PWDIR"/../gcc32
export PATH="$PWDIR/../gcc64/bin:$PWDIR/../gcc32/bin:$PATH"
export STRIP="$PWDIR/../gcc64/aarch64-elf/bin/strip"
export KBUILD_COMPILER_STRING=$("$PWDIR"/../gcc64/bin/aarch64-elf-gcc --version | head -n 1)

# Clang
echo -e "$green << cloning clang >> \n $white"
git clone --depth=1 https://gitlab.com/GhostMaster69-dev/cosmic-clang.git "$PWDIR"/../clang
export PATH="$PWDIR/../clang/bin:$PATH"
export KBUILD_COMPILER_STRING=$("$PWDIR"/../clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')


# Speed up build process
MAKE="./makeparallel"
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

start_build() {
        echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
        echo -e "$blue***********************************************"
        echo "          BUILDING KERNEL          "
        echo -e "***********************************************$nocol"
        make $KERNEL_DEFCONFIG O=out CC=clang
        make -j$(nproc --all) O=out \
                                      ARCH=arm64 \
                                      LLVM=1 \
                                      LLVM_IAS=1 \
                                      AR=llvm-ar \
                                      NM=llvm-nm \
                                      LD=ld.lld \
                                      OBJCOPY=llvm-objcopy \
                                      OBJDUMP=llvm-objdump \
                                      STRIP=llvm-strip \
                                      CC=clang \
                                      CROSS_COMPILE=aarch64-linux-gnu- \
                                      CROSS_COMPILE_ARM32=arm-linux-gnueabi-  2>&1 | tee error.log
        export IMG="$MY_DIR"/out/arch/arm64/boot/Image.gz
        export dtbo="$MY_DIR"/out/arch/arm64/boot/dtbo.img
        export dtb="$MY_DIR"/out/arch/arm64/boot/dtb.img

        find out/arch/arm64/boot/dts/ -name '*.dtb' -exec cat {} + >out/arch/arm64/boot/dtb
        if [ -f "out/arch/arm64/boot/Image.gz" ] && [ -f "out/arch/arm64/boot/dtbo.img" ] && [ -f "out/arch/arm64/boot/dtb" ]; then
                echo "------ Finishing  Build ------"
                git clone -q https://github.com/Sweet-stuff/AnyKernel3
                cp out/arch/arm64/boot/Image.gz AnyKernel3
                cp out/arch/arm64/boot/dtb AnyKernel3
                cp out/arch/arm64/boot/dtbo.img AnyKernel3
                rm -f *zip
                cd AnyKernel3
                sed -i "s/is_slot_device=0/is_slot_device=auto/g" anykernel.sh
                zip -r9 "../${zipname}" * -x '*.git*' README.md *placeholder >> /dev/null
                cd ..
                rm -rf AnyKernel3
                echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
                echo ""
                echo -e ${zipname} " is ready!"
                mv ${zipname} ZIPOUT/
                echo ""
        else
                echo -e "\n Compilation Failed!"
        fi
}

stable_build() {
for ((i=1; i<=4; i++))
do
    case $i in
        1)
            git reset --hard ${commit_sha}
            echo "OSS Ksu"
            export zipname="perf+-KernelSU-OSS-Stable-sweet-${date}.zip"
            start_build
            ;;
        *)
            echo "Error"
            ;;
    esac
done

}

canary_upload() {
TOKEN="$TG_TOKEN"
CHAT_ID="-1001980325626"
MESSAGE="ElectroKernel Canary ${date}"
DIRECTORY="$PWDIR/13/ZIPOUT"
# Đường dẫn đến thư mục chứa các file zip
FOLDER_PATH="$PWDIR/13/ZIPOUT"

# Tạo một mảng chứa các file zip
declare -a FILE_ARRAY

# Lặp qua tất cả các file zip trong thư mục và thêm vào mảng
for FILE_PATH in "$FOLDER_PATH"/*.zip; do
  FILE_ARRAY+=("-F" "document=@\"$FILE_PATH\"")
done

# Gửi tin nhắn với cả 4 file đính kèm
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendDocument" \
  -F chat_id="$CHAT_ID" \
  "${FILE_ARRAY[@]}"
}

stable_upload() {
TOKEN="$TG_TOKEN"
CHAT_ID="-1001980325626"
MESSAGE="ElectroKernel Stable ${date}"
DIRECTORY="$PWDIR/13/ZIPOUT"
for file in "$DIRECTORY"/*.zip
do
    curl -F document=@"$file" \
         -F chat_id="$CHAT_ID" \
         -F caption="$MESSAGE" \
         "https://api.telegram.org/bot$TOKEN/sendDocument"
done
}

input=$1

if [ "$input" == "canary" ]; then
        canary_build
        canary_upload
elif [ "$input" == "stable" ]; then
        stable_build
        stable_upload
else
        echo "Error"
fi
