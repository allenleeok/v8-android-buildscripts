#!/bin/bash -e
source $(dirname $0)/env.sh
BUILD_TYPE="Release"
# BUILD_TYPE="Debug"

GN_ARGS_BASE='
  is_debug = true
  symbol_level=2
  v8_enable_backtrace = true
  v8_enable_slow_dchecks = true
  v8_optimized_debug = false
  v8_target_cpu = "arm"
  target_os="android"
  target_cpu="arm"
  is_component_build=true
  v8_android_log_stdout=true
  v8_use_external_startup_data=false
  v8_use_snapshot=true
  v8_enable_debugging_features=true
  v8_enable_embedded_builtins=true
  is_clang=true
  use_custom_libcxx=false
  v8_enable_i18n_support=false
'

# if [[ ${NO_INTL} -eq "1" ]]; then
#   GN_ARGS_BASE="${GN_ARGS_BASE} v8_enable_i18n_support=false"
# fi

# if [[ "$BUILD_TYPE" = "Debug" ]]
# then
#   GN_ARGS_BUILD_TYPE='
#     is_debug=true
#     symbol_level=2
#   '
# else
#   GN_ARGS_BUILD_TYPE='
#     is_debug=false
#   '
# fi

NINJA_PARAMS=""

if [[ ${CIRCLECI} ]]; then
  NINJA_PARAMS="-j4"
fi

cd $V8_DIR

function normalize_arch_for_android()
{
  local arch=$1
  case "$1" in
    arm)
      echo "armeabi-v7a"
      ;;
    x86)
      echo "x86"
      ;;
    arm64)
      echo "arm64-v8a"
      ;;
    x64)
      echo "x86_64"
      ;;
    *)
      echo "Invalid arch - $arch" >&2
      exit 1
      ;;
  esac
}

function build_arch()
{
    local arch=$1
    local arch_for_android=$(normalize_arch_for_android $arch)

    # echo "Build v8 $arch variant NO_INTL=${NO_INTL}"
    if [[ "$arch" = "arm64" ]]; then
      # V8 mksnapshot will have alignment exception for lite mode, workaround to turn it off.
      gn gen --args="$GN_ARGS_BASE $GN_ARGS_BUILD_TYPE v8_enable_lite_mode=false" out.v8.$arch
    else
      gn gen --args="$GN_ARGS_BASE $GN_ARGS_BUILD_TYPE v8_enable_lite_mode=true" out.v8.$arch
    fi

    if [[ ${MKSNAPSHOT_ONLY} -eq "1" ]]; then
      date ; ninja ${NINJA_PARAMS} -C out.v8.$arch run_mksnapshot_default ; date
    else
      date ; ninja ${NINJA_PARAMS} -C out.v8.$arch libv8 ; date

      mkdir -p $BUILD_DIR/lib/$arch_for_android
      cp -f out.v8.$arch/libv8.so $BUILD_DIR/lib/$arch_for_android/libv8.so
      mkdir -p $BUILD_DIR/lib.unstripped/$arch_for_android
      cp -f out.v8.$arch/lib.unstripped/libv8.so $BUILD_DIR/lib.unstripped/$arch_for_android/libv8.so
    fi

    mkdir -p $BUILD_DIR/tools/$arch_for_android
    cp -f out.v8.$arch/clang_*/mksnapshot $BUILD_DIR/tools/$arch_for_android/mksnapshot
}

build_arch "arm"
# build_arch "x86"
# build_arch "arm64"
# build_arch "x64"
