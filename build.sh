#!/usr/bin/env sh

# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2020-present Leverex (leverex@liser.tv)

set -e

# Get source directory of our build script
BASE_DIR="$( cd "$( dirname "$(readlink -f "$0")" )" >/dev/null && pwd )"

# Path to config file
CONFIG_FILE="${BASE_DIR}/.env"

# shellcheck disable=SC2086
if [ ! -f "${CONFIG_FILE}" ] && [ -z ${CI+x} ]; then
    echo "Error: You need to create a .env file." \
         "See .env.example for reference."
    exit 1
fi

# When running in CI do not source configuration file
# shellcheck disable=SC2086
if [ -z ${CI+x} ]; then
    set -a
    # shellcheck source=.env disable=SC1091
    . "${CONFIG_FILE}"
    set +a
fi

# Get number of available cpu cores
NUM_CPU="$(grep -c ^processor /proc/cpuinfo)"

# Use all available cpu cores * 1.5
if [ -n "${NUM_CPU}" ] && [ "${NUM_CPU}" -eq "${NUM_CPU}" ]; then
    MAKE_THREADS="$(( NUM_CPU * 3/2 ))"
fi

HOST_DEPENDS="autoconf automake cmake diffutils file g++ gcc git \
             libtool make pkgconfig texinfo \
             brotli-static bzip2-static expat-static \
             fontconfig-static freetype-static fribidi-static \
             libass-dev libpng-static zlib-static"

# Install build host dependencies
# shellcheck disable=SC2086
apk update && apk add ${HOST_DEPENDS}

# Patch pkgconfig files
sed -i "s,-lbrotlicommon$,-lbrotlicommon-static," /usr/lib/pkgconfig/libbrotlicommon.pc
sed -i "s,-lbrotlidec$,-lbrotlidec-static," /usr/lib/pkgconfig/libbrotlidec.pc
sed -i "s,-lbrotlienc$,-lbrotlienc-static," /usr/lib/pkgconfig/libbrotlienc.pc

# Setup the environment for the non-root user
adduser -D "${BUILD_USER}" || true

SOURCE_DIR="${BASE_DIR}/sources"
TARGET_DIR="${BASE_DIR}/build"

install -d -m 0755 -o "${BUILD_USER}" "${SOURCE_DIR}" "${TARGET_DIR}"

# Compile as non-root user
su - "${BUILD_USER}" -s "/bin/sh" << SHELL

set -e

# Setup the build environment variables
export PATH="${TARGET_DIR}/bin:\${PATH}"
export PKG_CONFIG_PATH="${TARGET_DIR}/lib/pkgconfig:/usr/lib/pkgconfig"
export CFLAGS="-I${TARGET_DIR}/include -I/usr/include --static"
export LDFLAGS="-L${TARGET_DIR}/lib -L/usr/lib -static"
export LDEXEFLAGS="-static"

if [ -n "${MAKE_THREADS}" ]; then
    export MAKEFLAGS="-j${MAKE_THREADS}"
fi

# Build nasm
cd "${SOURCE_DIR}"
wget https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2
tar -xjf nasm-2.14.02.tar.bz2
cd nasm-*
./autogen.sh
./configure --prefix="${TARGET_DIR}"
make
make install

# Build libx264
cd "${SOURCE_DIR}"
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264
./configure --prefix="${TARGET_DIR}" --enable-static --enable-pic
make
make install

# Build libx265
cd "${SOURCE_DIR}"
wget -O x265.tar.gz https://bitbucket.org/multicoreware/x265_git/get/master.tar.gz
tar -xzf x265.tar.gz
cd multicoreware-x265_git-*/build/linux
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${TARGET_DIR}" -DENABLE_SHARED:BOOL=OFF -DBUILD_SHARED_LIBS:BOOL=OFF -DSTATIC_LINK_CRT:BOOL=OFF -DENABLE_CLI:BOOL=OFF ../../source
make
make install

# Build libfdk-aac
cd "${SOURCE_DIR}"
git clone --depth 1 https://github.com/mstorsjo/fdk-aac
cd fdk-aac
autoreconf -fiv
./configure --prefix="${TARGET_DIR}" --disable-shared --enable-static
make
make install

# Build libmp3lame
cd "${SOURCE_DIR}"
wget https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
tar -xzf lame-3.100.tar.gz
cd lame-*
./configure --prefix="${TARGET_DIR}" --disable-shared --enable-nasm
make
make install

# Build libogg
cd "${SOURCE_DIR}"
wget https://downloads.xiph.org/releases/ogg/libogg-1.3.4.tar.gz
tar -xzf libogg-1.3.4.tar.gz
cd libogg-*
./configure --prefix="${TARGET_DIR}" --disable-shared
make
make install

# Build libvorbis
cd "${SOURCE_DIR}"
wget https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz
tar -xzf libvorbis-1.3.7.tar.gz
cd libvorbis-*
./configure --prefix="${TARGET_DIR}" --disable-shared --disable-oggtest
make
make install

# Build libvpx
cd "${SOURCE_DIR}"
git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git
cd libvpx
./configure --prefix="${TARGET_DIR}" --disable-shared --enable-pic --disable-examples --disable-unit-tests --enable-vp9-highbitdepth
make
make install

# Build ffmpeg
cd "${SOURCE_DIR}"
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar -xjf ffmpeg-snapshot.tar.bz2
cd ffmpeg
./configure \
  --disable-shared \
  --disable-doc \
  --enable-runtime-cpudetect \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfontconfig \
  --enable-libfreetype \
  --enable-libfribidi \
  --enable-libmp3lame \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  --enable-pthreads \
  --enable-static \
  --enable-version3 \
  --extra-libs="-lpthread -lm" \
  --pkg-config-flags="--static" \
  --prefix="${TARGET_DIR}"
make
make install
SHELL

# Prepare files for release
cp -av "${TARGET_DIR}/bin/ffmpeg" "${BASE_DIR}/dist/"
cp -av "${TARGET_DIR}/bin/ffprobe" "${BASE_DIR}/dist/"

exit 0
