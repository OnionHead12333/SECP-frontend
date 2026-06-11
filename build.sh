#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="${ROOT_DIR}/mobile"
OUTPUT_DIR="${ROOT_DIR}/output"
STAGING_DIR=""

# 编译前可通过环境变量传入（与 flutter run / flutter build apk 的 --dart-define 一致）
#
# 示例（连云服务器 release 包）：
#   export API_BASE=http://120.46.62.182:8080/api
#   export AMAP_ANDROID_KEY=你的高德AndroidKey
#   export XFYUN_IAT_APP_ID=你的AppId
#   export XFYUN_IAT_API_KEY=你的ApiKey
#   export XFYUN_IAT_API_SECRET=你的ApiSecret
#   ./build.sh
#
# 路径含中文时可启用临时目录编译：export FORCE_ASCII_BUILD=1

API_BASE="${API_BASE:-http://192.168.x.x:8080/api}"
AMAP_ANDROID_KEY="${AMAP_ANDROID_KEY:-}"
XFYUN_IAT_APP_ID="${XFYUN_IAT_APP_ID:-}"
XFYUN_IAT_API_KEY="${XFYUN_IAT_API_KEY:-}"
XFYUN_IAT_API_SECRET="${XFYUN_IAT_API_SECRET:-}"
BUILD_MODE="${BUILD_MODE:-release}"

cleanup_staging() {
  if [[ -n "${STAGING_DIR}" && -d "${STAGING_DIR}" ]]; then
    rm -rf "${STAGING_DIR}"
  fi
}

path_has_non_ascii() {
  local p="$1"
  local i c
  for ((i = 0; i < ${#p}; i++)); do
    c="${p:i:1}"
    case "${c}" in
      [a-zA-Z0-9/\\._:-]) ;;
      *) return 0 ;;
    esac
  done
  return 1
}

should_use_ascii_staging() {
  if [[ "${SKIP_ASCII_BUILD:-}" == "1" ]]; then
    return 1
  fi
  if [[ "${FORCE_ASCII_BUILD:-}" == "1" ]]; then
    return 0
  fi
  path_has_non_ascii "${ROOT_DIR}"
}

sync_project_to_staging() {
  local dest="$1"
  rm -rf "${dest}"
  mkdir -p "${dest}/mobile" "${dest}/packages"
  cp -R "${ROOT_DIR}/mobile/." "${dest}/mobile/"
  cp -R "${ROOT_DIR}/packages/." "${dest}/packages/"
}

prepare_work_mobile_dir() {
  WORK_MOBILE_DIR="${MOBILE_DIR}"

  if ! should_use_ascii_staging; then
    return 0
  fi

  STAGING_DIR="C:/secp-flutter-build/build-$$"
  if [[ ! -d "C:/secp-flutter-build" ]]; then
    STAGING_DIR="/tmp/secp-flutter-build-$$"
  fi
  mkdir -p "$(dirname "${STAGING_DIR}")"

  trap cleanup_staging EXIT
  echo "==> 项目路径含中文等非 ASCII 字符，复制到纯英文目录后编译"
  echo "    原路径: ${ROOT_DIR}"
  echo "    临时路径: ${STAGING_DIR}"
  sync_project_to_staging "${STAGING_DIR}"
  WORK_MOBILE_DIR="${STAGING_DIR}/mobile"
}

if [[ "${BUILD_MODE}" != "release" && "${BUILD_MODE}" != "debug" ]]; then
  echo "错误: BUILD_MODE 只能是 release 或 debug，当前为: ${BUILD_MODE}"
  exit 1
fi

DART_DEFINES=(
  "--dart-define=API_BASE=${API_BASE}"
)

if [[ -n "${AMAP_ANDROID_KEY}" ]]; then
  export AMAP_ANDROID_KEY
  DART_DEFINES+=("--dart-define=AMAP_ANDROID_KEY=${AMAP_ANDROID_KEY}")
fi
if [[ -n "${XFYUN_IAT_APP_ID}" ]]; then
  DART_DEFINES+=("--dart-define=XFYUN_IAT_APP_ID=${XFYUN_IAT_APP_ID}")
fi
if [[ -n "${XFYUN_IAT_API_KEY}" ]]; then
  DART_DEFINES+=("--dart-define=XFYUN_IAT_API_KEY=${XFYUN_IAT_API_KEY}")
fi
if [[ -n "${XFYUN_IAT_API_SECRET}" ]]; then
  DART_DEFINES+=("--dart-define=XFYUN_IAT_API_SECRET=${XFYUN_IAT_API_SECRET}")
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "错误: 未找到 flutter，请先安装 Flutter SDK 并配置 PATH"
  exit 1
fi

prepare_work_mobile_dir

echo "==> SECP-frontend 编译开始"
echo "    编译目录: ${WORK_MOBILE_DIR}"
echo "    BUILD_MODE: ${BUILD_MODE}"
echo "    API_BASE: ${API_BASE}"

cd "${WORK_MOBILE_DIR}"
flutter pub get
flutter build apk "--${BUILD_MODE}" "${DART_DEFINES[@]}"

mkdir -p "${OUTPUT_DIR}"
if [[ "${BUILD_MODE}" == "release" ]]; then
  APK_FILE="build/app/outputs/flutter-apk/app-release.apk"
  OUT_NAME="smart-elderly-care-mobile-release.apk"
else
  APK_FILE="build/app/outputs/flutter-apk/app-debug.apk"
  OUT_NAME="smart-elderly-care-mobile-debug.apk"
fi

cp "${APK_FILE}" "${OUTPUT_DIR}/${OUT_NAME}"

echo "==> 编译完成"
echo "    产物: ${OUTPUT_DIR}/${OUT_NAME}"
ls -lh "${OUTPUT_DIR}/${OUT_NAME}"
