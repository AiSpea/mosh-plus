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
ARTIFACT_NAME=${ARTIFACT_NAME:-"mosh-plus-${PROJECT_VERSION}-${GIT_REVISION}-linux-amd64"}

# Allow callers to pass additional configure flags through the CONFIGURE_FLAGS
# environment variable without editing the script.
CONFIGURE_FLAGS=${CONFIGURE_FLAGS:-""}
MAKEFLAGS=${MAKEFLAGS:-"-j$(nproc)"}

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
sha256sum "${TARBALL_PATH}" > "${TARBALL_PATH}.sha256"

echo "Release artifacts written to:"
echo "  ${TARBALL_PATH}"
echo "  ${TARBALL_PATH}.sha256"
