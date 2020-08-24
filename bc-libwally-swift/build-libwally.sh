#!/usr/bin/env sh
set -e # abort if any command fails

MIN_IOS_VERSION="10.0"
PROJ_ROOT="${PWD}/CLibWally/libwally-core"
BUILD_ROOT=${PROJ_ROOT}/build
OUTPUT_DIR=${BUILD_ROOT}/fat

build()
{
  ARCH=$1
  TARGET=$2
  HOST=$3
  SDK=$4
  BITCODE=$5
  VERSION=$6
  SDK_PATH=`xcrun -sdk ${SDK} --show-sdk-path`

  export PREFIX=${BUILD_ROOT}/${ARCH}
  export CFLAGS="-O3 -arch ${ARCH} -isysroot ${SDK_PATH} ${BITCODE} ${VERSION} -target ${TARGET}"
  export CXXFLAGS="-O3 -arch ${ARCH} -isysroot ${SDK_PATH} ${BITCODE} ${VERSION} -target ${TARGET}"

  export LDFLAGS="-arch ${ARCH}"
  export CC="$(xcrun --sdk ${SDK} -f clang) -arch ${ARCH} -isysroot ${SDK_PATH}"
  export CXX="$(xcrun --sdk ${SDK} -f clang++) -arch ${ARCH} -isysroot ${SDK_PATH}"

  pushd ${PROJ_ROOT}

  PKG_CONFIG_ALLOW_CROSS=1 PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig ./configure --disable-shared --host=${HOST} --enable-static --prefix=$PREFIX

  make clean
  make
  make install

  popd
}

combine()
{
  LIB_NAME=$1

  mkdir -p ${OUTPUT_DIR}/lib
  lipo -create -output $OUTPUT_DIR/lib/${LIB_NAME}.a \
    ${BUILD_ROOT}/arm64/lib/${LIB_NAME}.a \
    ${BUILD_ROOT}/armv7/lib/${LIB_NAME}.a \
    ${BUILD_ROOT}/i386/lib/${LIB_NAME}.a \
    ${BUILD_ROOT}/x86_64/lib/${LIB_NAME}.a
}

rm -rf ${BUILD_ROOT}
if [ ! -d ${BUILD_ROOT} ]; then
  pushd ${PROJ_ROOT}
  sh ./tools/autogen.sh
  popd
  mkdir -p ${BUILD_ROOT}
fi

set +v

build "arm64" "aarch64-apple-ios" "arm-apple-darwin" "iphoneos" "-fembed-bitcode" "-mios-version-min=${MIN_IOS_VERSION}"
build "armv7" "armv7-apple-ios" "arm-apple-darwin" "iphoneos" "-fembed-bitcode" "-mios-version-min=${MIN_IOS_VERSION}" # MIN_IOS_VERSION must be one of arm7 supported ones to. Else remove this line.
build "i386" "i386-apple-ios" "i386-apple-darwin" "iphonesimulator" "-fembed-bitcode-marker" "-mios-simulator-version-min=${MIN_IOS_VERSION}" # same as arm7:  MIN_IOS_VERSION must be one of arm7 supported ones.
build "x86_64" "x86_64-apple-ios13.0-macabi" "x86_64-apple-darwin" "macosx" "-fembed-bitcode" "-mios-version-min=${MIN_IOS_VERSION}" # This is the build that runs under Catalyst
# build "x86_64" "x86_64-apple-ios" "x86_64-apple-darwin" "iphonesimulator" "embed-bitcode-market" "-mios-simulator-version-min=${MIN_IOS_VERSION}" #obsolete due to x86_64-apple-ios13.0-macabi

combine "libsecp256k1"
combine "libwallycore"
mkdir -p ${OUTPUT_DIR}/include/
cp -R ${BUILD_ROOT}/armv7/include/* ${OUTPUT_DIR}/include/
