#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
MATRIX="${ANSIBLE_CORE_MATRIX:-2.16.19 2.17.14 2.18.18 2.19.11 2.20.7 2.21.2}"
USE_DOCKER="${USE_DOCKER:-false}"
WORK_ROOT="${DEPENDENCY_MATRIX_WORK_ROOT:-$(mktemp -d /tmp/fmcansible-deps.XXXXXX)}"

cleanup() {
  if [[ "${KEEP_DEPENDENCY_MATRIX_WORKDIR:-0}" != "1" ]]; then
    rm -rf "${WORK_ROOT}"
  else
    echo "Kept dependency-matrix workdir: ${WORK_ROOT}"
  fi
}
trap cleanup EXIT

export ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP:-/tmp/ansible-local}"
export ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP:-/tmp/ansible-remote}"
mkdir -p "${ANSIBLE_LOCAL_TEMP}" "${ANSIBLE_REMOTE_TEMP}"

python_for_core() {
  case "$1" in
    2.16.*|2.17.*) echo "3.12" ;;
    2.18.*|2.19.*) echo "3.13" ;;
    2.20.*|2.21.*) echo "3.14" ;;
    *) echo "Unsupported ansible-core version: $1" >&2; return 1 ;;
  esac
}

test_in_docker() {
  version="$1"
  python_version="$(python_for_core "${version}")"
  version_root="${WORK_ROOT}/core-${version}"
  mkdir -p "${version_root}"

  echo
  echo "==> Testing ansible-core ${version} with Python ${python_version}"
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    --env USER=jenkins \
    --env LOGNAME=jenkins \
    --env CORE_VERSION="${version}" \
    --volume "${ROOT_DIR}:/src:ro" \
    --volume "${version_root}:/work" \
    "python:${python_version}" \
    /bin/sh -c '
      set -eu
      python -m venv /tmp/venv
      . /tmp/venv/bin/activate
      python -m pip install --disable-pip-version-check --upgrade pip
      python -m pip install --disable-pip-version-check "ansible-core==${CORE_VERSION}"
      printf "ansible-core==%s\n" "${CORE_VERSION}" > /tmp/constraints.txt
      python -m pip install --disable-pip-version-check \
        --requirement /src/requirements.txt --constraint /tmp/constraints.txt
      mkdir -p /work/dist /work/collections
      ansible-galaxy collection build /src --output-path /work/dist
      ANSIBLE_COLLECTIONS_PATH=/work/collections \
        ansible-galaxy collection install /work/dist/*.tar.gz --force
      ANSIBLE_COLLECTIONS_PATH=/work/collections \
        ansible-galaxy collection install cisco.nxos --force
      ansible --version
      ANSIBLE_COLLECTIONS_PATH=/work/collections ansible-galaxy collection list
    '
}

test_locally() {
  version="$1"
  venv="${WORK_ROOT}/venv-${version}"
  dist_dir="${WORK_ROOT}/dist-${version}"
  collections_path="${WORK_ROOT}/collections-${version}"

  echo
  echo "==> Testing ansible-core ${version} with ${PYTHON_BIN}"
  "${PYTHON_BIN}" -m venv "${venv}"
  # shellcheck disable=SC1091
  source "${venv}/bin/activate"
  python -m pip install --disable-pip-version-check --upgrade pip
  python -m pip install --disable-pip-version-check "ansible-core==${version}"
  constraint_file="${WORK_ROOT}/constraints-${version}.txt"
  printf 'ansible-core==%s\n' "${version}" > "${constraint_file}"
  python -m pip install --disable-pip-version-check \
    --requirement "${ROOT_DIR}/requirements.txt" --constraint "${constraint_file}"
  mkdir -p "${dist_dir}" "${collections_path}"
  ansible-galaxy collection build "${ROOT_DIR}" --output-path "${dist_dir}"
  ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
    ansible-galaxy collection install "${dist_dir}"/*.tar.gz --force
  ANSIBLE_COLLECTIONS_PATH="${collections_path}" \
    ansible-galaxy collection install cisco.nxos --force
  ansible --version
  ANSIBLE_COLLECTIONS_PATH="${collections_path}" ansible-galaxy collection list
  deactivate
}

for version in ${MATRIX}; do
  if [[ "${USE_DOCKER}" == "true" ]]; then
    test_in_docker "${version}"
  else
    test_locally "${version}"
  fi
done
