#!/bin/bash -e
source $(dirname $0)/env.sh

DIST_PACKAGE_DIR="${DIST_DIR}/packages/v8-android"
if [[ ${NO_INTL} -eq "1" ]]; then
  DIST_PACKAGE_DIR="${DIST_DIR}/packages/v8-android-nointl"
elif [[ ${MKSNAPSHOT_ONLY} -eq "1" ]]; then
  DIST_PACKAGE_DIR="${DIST_DIR}/packages/v8-android-tools"
fi


function createAAR() {
  printf "\n\n\t\t===================== create aar =====================\n\n"
  pushd .
  cd $ROOT_DIR/lib
  ./gradlew clean :v8-android:createAAR --project-prop distDir="$DIST_PACKAGE_DIR" --project-prop version="$VERSION"
  popd
}

function createUnstrippedLibs() {
  printf "\n\n\t\t===================== create unstripped libs =====================\n\n"
  DIST_LIB_UNSTRIPPED_DIR="$DIST_PACKAGE_DIR/lib.unstripped/v8-android/$VERSION"
  mkdir -p $DIST_LIB_UNSTRIPPED_DIR
  tar cfJ $DIST_LIB_UNSTRIPPED_DIR/libs.tar.xz -C $BUILD_DIR/lib.unstripped .
  unset DIST_LIB_UNSTRIPPED_DIR
}

function copyHeaders() {
  printf "\n\n\t\t===================== adding headers to $DIST_PACKAGE_DIR/include =====================\n\n"
  cp -Rf $V8_DIR/include $DIST_PACKAGE_DIR/include
}

function copyTools() {
  printf "\n\n\t\t===================== adding tools to $DIST_PACKAGE_DIR/tools =====================\n\n"
  cp -Rf $BUILD_DIR/tools $DIST_PACKAGE_DIR/tools
}


if [[ ${MKSNAPSHOT_ONLY} -eq "1" ]]; then
  mkdir -p $DIST_PACKAGE_DIR
  copyTools
else
  export ANDROID_HOME=${V8_DIR}/third_party/android_tools/sdk
  export ANDROID_NDK=${V8_DIR}/third_party/android_ndk
  export PATH=${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}
  yes | sdkmanager --licenses

  mkdir -p $DIST_PACKAGE_DIR
  createAAR
  createUnstrippedLibs
  copyHeaders
  copyTools
fi
