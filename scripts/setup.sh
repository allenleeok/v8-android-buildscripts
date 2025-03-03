#!/bin/bash -e
source $(dirname $0)/env.sh

GCLIENT_SYNC_ARGS="--reset --with_branch_head"
while getopts 'r:s' opt; do
  case ${opt} in
    r)
      GCLIENT_SYNC_ARGS+=" --revision $OPTARG"
      ;;
    s)
      GCLIENT_SYNC_ARGS+=" --no-history"
      ;;
  esac
done

# Install NDK
function installNDK() {
  pushd .
  cd $V8_DIR
  # wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux-x86_64.zip
  unzip -q /code/android-ndk-${NDK_VERSION}-linux-x86_64.zip
  # rm -f android-ndk-${NDK_VERSION}-linux-x86_64.zip
  popd
}

if [[ ! -d "$DEPOT_TOOLS_DIR" || ! -f "$DEPOT_TOOLS_DIR/gclient" ]]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $DEPOT_TOOLS_DIR
fi

gclient config --name v8 --unmanaged "https://chromium.googlesource.com/v8/v8.git"

if [[ ${MKSNAPSHOT_ONLY} -eq "1" ]]; then
  gclient sync $GCLIENT_SYNC_ARGS
else
  gclient sync --deps=android $GCLIENT_SYNC_ARGS
  sudo bash -c 'v8/build/install-build-deps-android.sh'

  # Workaround to install missing sysroot
  gclient sync

  installNDK
fi
