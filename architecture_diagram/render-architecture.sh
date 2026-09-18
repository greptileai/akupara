#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required_d2_version="v0.9.0"

if ! command -v d2 >/dev/null 2>&1; then
  echo "D2 ${required_d2_version} is required. Install it from https://github.com/d2lang/d2/releases/tag/${required_d2_version}." >&2
  exit 1
fi

installed_d2_version="$(d2 --version)"
if [[ "${installed_d2_version}" != "${required_d2_version}" ]]; then
  echo "Expected D2 ${required_d2_version}; found ${installed_d2_version}." >&2
  exit 1
fi

d2 \
  "${repository_root}/Greptile_architecture.current.d2" \
  "${repository_root}/Greptile_architecture.current.svg"
