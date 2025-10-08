#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/build/release"
STAGE_DIR="${BUILD_DIR}/stage"
ARTIFACT_DIR="${BUILD_DIR}/artifacts"

mkdir -p "${STAGE_DIR}" "${ARTIFACT_DIR}"

# Derive the project version from configure.ac and include the short git SHA so
# users can quickly map artifacts back to a commit.
PROJECT_VERSION=${PROJECT_VERSION:-$(sed -n 's/AC_INIT([^,]*, *\[\([^]]*\)\],.*/\1/p' "${ROOT_DIR}/configure.ac")}
GIT_REVISION=$(git -C "${ROOT_DIR}" rev-parse --short HEAD)

TARGET_OS=${TARGET_OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}
TARGET_ARCH_RAW=${TARGET_ARCH:-$(uname -m)}

case "${TARGET_ARCH_RAW}" in
  x86_64|amd64)
    TARGET_ARCH_CANON="amd64"
    FPM_ARCH_DEB="amd64"
    FPM_ARCH_RPM="x86_64"
    ;;
  arm64|aarch64)
    TARGET_ARCH_CANON="arm64"
    FPM_ARCH_DEB="arm64"
    FPM_ARCH_RPM="aarch64"
    ;;
  *)
    TARGET_ARCH_CANON="${TARGET_ARCH_RAW}"
    FPM_ARCH_DEB="${TARGET_ARCH_RAW}"
    FPM_ARCH_RPM="${TARGET_ARCH_RAW}"
    ;;
esac

ARTIFACT_NAME=${ARTIFACT_NAME:-"mosh-plus-${PROJECT_VERSION}-${GIT_REVISION}-${TARGET_OS}-${TARGET_ARCH_CANON}"}

# Allow callers to pass additional configure flags through the CONFIGURE_FLAGS
# environment variable without editing the script.
CONFIGURE_FLAGS=${CONFIGURE_FLAGS:-""}

if command -v nproc >/dev/null 2>&1; then
  DEFAULT_JOBS="-j$(nproc)"
elif command -v getconf >/dev/null 2>&1; then
  DEFAULT_JOBS="-j$(getconf _NPROCESSORS_ONLN)"
else
  DEFAULT_JOBS=""
fi

MAKEFLAGS=${MAKEFLAGS:-"${DEFAULT_JOBS}"}

pushd "${ROOT_DIR}" >/dev/null

./autogen.sh
CONFIGURE_ARGS=("--prefix=/usr/local")
if [[ -n "${CONFIGURE_FLAGS}" ]]; then
  # shellcheck disable=SC2206 # Intentional word splitting to support multiple flags.
  EXTRA_ARGS=(${CONFIGURE_FLAGS})
  CONFIGURE_ARGS+=("${EXTRA_ARGS[@]}")
fi
./configure "${CONFIGURE_ARGS[@]}"
make ${MAKEFLAGS}
rm -rf "${STAGE_DIR}"
make install DESTDIR="${STAGE_DIR}"

popd >/dev/null

TARBALL_PATH="${ARTIFACT_DIR}/${ARTIFACT_NAME}.tar.gz"
INSTALL_ROOT="${STAGE_DIR}/usr/local"

if [[ ! -d "${INSTALL_ROOT}" ]]; then
  echo "Expected install root ${INSTALL_ROOT} to exist" >&2
  exit 1
fi

tar -C "${INSTALL_ROOT}" -czf "${TARBALL_PATH}" .

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${TARBALL_PATH}" > "${TARBALL_PATH}.sha256"
else
  shasum -a 256 "${TARBALL_PATH}" > "${TARBALL_PATH}.sha256"
fi

PACKAGE_FORMATS=${PACKAGE_FORMATS:-""}
if [[ -n "${PACKAGE_FORMATS}" ]]; then
  IFS=',' read -r -a FORMATS <<< "${PACKAGE_FORMATS}"
  for format in "${FORMATS[@]}"; do
    case "${format}" in
      deb|rpm)
        if ! command -v fpm >/dev/null 2>&1; then
          echo "Skipping ${format} package: fpm is not installed" >&2
          continue
        fi
        PACKAGE_ITERATION=${PACKAGE_ITERATION:-${GIT_REVISION}}
        PACKAGE_NAME=${PACKAGE_NAME:-mosh-plus}
        PACKAGE_DESCRIPTION=${PACKAGE_DESCRIPTION:-"Enhanced Mosh build with mouse support"}
        PACKAGE_URL=${PACKAGE_URL:-"https://github.com/mosh-plus/mosh-plus"}
        PACKAGE_LICENSE=${PACKAGE_LICENSE:-"GPL-3.0-or-later"}
        PACKAGE_MAINTAINER=${PACKAGE_MAINTAINER:-"Mosh Plus Team <support@mosh-plus.invalid>"}
        case "${format}" in
          deb)
            OUTPUT_PATH="${ARTIFACT_DIR}/${PACKAGE_NAME}_${PROJECT_VERSION}-${PACKAGE_ITERATION}_${FPM_ARCH_DEB}.deb"
            fpm -s dir -t deb \
              -n "${PACKAGE_NAME}" \
              -v "${PROJECT_VERSION}" \
              --iteration "${PACKAGE_ITERATION}" \
              --architecture "${FPM_ARCH_DEB}" \
              --description "${PACKAGE_DESCRIPTION}" \
              --url "${PACKAGE_URL}" \
              --license "${PACKAGE_LICENSE}" \
              --maintainer "${PACKAGE_MAINTAINER}" \
              --prefix /usr/local \
              --package "${OUTPUT_PATH}" \
              -C "${STAGE_DIR}" usr/local || {
                echo "Failed to build deb package" >&2
                continue
              }
            ;;
          rpm)
            OUTPUT_PATH="${ARTIFACT_DIR}/${PACKAGE_NAME}-${PROJECT_VERSION}-${PACKAGE_ITERATION}.${FPM_ARCH_RPM}.rpm"
            fpm -s dir -t rpm \
              -n "${PACKAGE_NAME}" \
              -v "${PROJECT_VERSION}" \
              --iteration "${PACKAGE_ITERATION}" \
              --architecture "${FPM_ARCH_RPM}" \
              --description "${PACKAGE_DESCRIPTION}" \
              --url "${PACKAGE_URL}" \
              --license "${PACKAGE_LICENSE}" \
              --maintainer "${PACKAGE_MAINTAINER}" \
              --prefix /usr/local \
              --package "${OUTPUT_PATH}" \
              -C "${STAGE_DIR}" usr/local || {
                echo "Failed to build rpm package" >&2
                continue
              }
            ;;
        esac
        ;;
      *)
        echo "Unsupported package format: ${format}" >&2
        ;;
    esac
  done
fi

echo "Release artifacts written to:"
echo "  ${TARBALL_PATH}"
echo "  ${TARBALL_PATH}.sha256"
if [[ -n "${PACKAGE_FORMATS}" ]]; then
  for format in "${FORMATS[@]}"; do
    case "${format}" in
      deb)
        echo "  ${ARTIFACT_DIR}/${PACKAGE_NAME}_${PROJECT_VERSION}-${PACKAGE_ITERATION}_${FPM_ARCH_DEB}.deb"
        ;;
      rpm)
        echo "  ${ARTIFACT_DIR}/${PACKAGE_NAME}-${PROJECT_VERSION}-${PACKAGE_ITERATION}.${FPM_ARCH_RPM}.rpm"
        ;;
    esac
  done
fi
