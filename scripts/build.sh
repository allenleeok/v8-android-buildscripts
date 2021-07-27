#!/bin/bash -e
source $(dirname $0)/env.sh
BUILD_TYPE="Release"
# BUILD_TYPE="Debug"

GN_ARGS_BASE="
  v8_enable_backtrace=false
  v8_enable_slow_dchecks=true
  v8_optimized_debug=false
  target_os=\"${PLATFORM}\"
  is_component_build=true
  v8_android_log_stdout=true
  v8_use_external_startup_data=false
  v8_use_snapshot=true
  v8_enable_debugging_features=false
  v8_enable_embedded_builtins=true
  is_clang=true
  use_custom_libcxx=false
  v8_enable_i18n_support=false
"

if [[ ${NO_INTL} = "1" ]]; then
  GN_ARGS_BASE="${GN_ARGS_BASE} v8_enable_i18n_support=false"
fi

if [[ ${DISABLE_JIT} != "false" ]]; then
  GN_ARGS_BASE="${GN_ARGS_BASE} v8_enable_lite_mode=true"
fi

if [[ "$BUILD_TYPE" = "Debug" ]]
then
  GN_ARGS_BUILD_TYPE='
    is_debug=true
    symbol_level=2
  '
else
  GN_ARGS_BUILD_TYPE='
    is_debug=false
  '
fi

NINJA_PARAMS=""

if [[ ${CIRCLECI} ]]; then
  NINJA_PARAMS="-j4"
fi

cd ${V8_DIR}

function normalize_arch_for_platform()
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
      echo "Invalid arch - ${arch}" >&2
      exit 1
      ;;
  esac
}

function build_arch()
{
  local arch=$1
  local platform_arch=$(normalize_arch_for_platform $arch)

  local target=''
  local target_ext=''
  if [[ ${PLATFORM} = "android" ]]; then
    target="mtv8"
    target_ext=".so"
  else
    exit 1
  fi

  echo "Build v8 ${arch} variant NO_INTL=${NO_INTL}"
  gn gen --args="${GN_ARGS_BASE} ${GN_ARGS_BUILD_TYPE} v8_target_cpu=\"${arch}\" target_cpu=\"${arch}\"" "out.v8.${arch}"

  if [[ ${MKSNAPSHOT_ONLY} = "1" ]]; then
    date ; ninja ${NINJA_PARAMS} -C "out.v8.${arch}" run_mksnapshot_default ; date
  else
    date ; ninja ${NINJA_PARAMS} -C "out.v8.${arch}" ${target} ; date

    mkdir -p "${BUILD_DIR}/lib/${platform_arch}"
    cp -f "out.v8.${arch}/${target}${target_ext}" "${BUILD_DIR}/lib/${platform_arch}/${target}${target_ext}"

    if [[ -d "out.v8.${arch}/lib.unstripped" ]]; then
      mkdir -p "${BUILD_DIR}/lib.unstripped/${platform_arch}"
      cp -f "out.v8.${arch}/lib.unstripped/${target}${target_ext}" "${BUILD_DIR}/lib.unstripped/${platform_arch}/${target}${target_ext}"
    fi
  fi

  mkdir -p "${BUILD_DIR}/tools/${platform_arch}"
  cp -f out.v8.${arch}/clang_*/mksnapshot "${BUILD_DIR}/tools/${platform_arch}/mksnapshot"
}

if [[ ${PLATFORM} = "android" ]]; then
  build_arch "arm"
  build_arch "arm64"
fi
