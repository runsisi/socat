#!/bin/sh

# Customize these parameters according to your environment
ANDROID_NDK="${HOME}/bin/android-ndk-r6b"

# Check for parameters
if [ ! -d "${ANDROID_NDK}" ]; then
 echo "Android NDK not found in ${ANDROID_NDK}, please edit $0 to fix it."
 exit 1
fi

if [ ! -e "${ANDROID_NDK}/build/tools/make-standalone-toolchain.sh" ]; then
 echo "Your Android NDK is not compatible (make-standalone-toolchain.sh not found)."
 echo "Android NDK r6b is known to work."
 exit 1
fi

# Extract the Android toolchain from NDK
ANDROID_PLATFORM="android-3"
ROOT="`pwd`"
OUT="${ROOT}/out"
${ANDROID_NDK}/build/tools/make-standalone-toolchain.sh \
 --ndk-dir="${ANDROID_NDK}" \
 --platform="${ANDROID_PLATFORM}" \
 --install-dir="${OUT}/toolchain" \
 || exit 1
# Remove resolv.h because it is quite unusable as is
rm ${OUT}/toolchain/sysroot/usr/include/resolv.h

# Create configure script
cd ${ROOT}
autoconf || exit 1

# Create config.h and Makefile
cd ${OUT}
${ROOT}/configure \
 --host \
 --disable-openssl \
 --disable-unix \
 CC="${OUT}/toolchain/bin/arm-linux-androideabi-gcc" \
 || exit 1

# Replace misconfigured values in config.h
mv config.h config.old
cat config.old \
 | sed 's/CRDLY_SHIFT/CRDLY_SHIFT 9/' \
 | sed 's/TABDLY_SHIFT/TABDLY_SHIFT 11/' \
 | sed 's/CSIZE_SHIFT/CSIZE_SHIFT 4/' \
 > config.h

# Compile
make socat || exit 1

# Done
echo "Build finished, socat has been generated successfuly in out/socat"

