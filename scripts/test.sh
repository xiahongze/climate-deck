#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export XDG_CONFIG_HOME="$test_dir/config"
export XDG_CACHE_HOME="$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
export DBUS_SESSION_BUS_ADDRESS="unix:path=$test_dir/no-bus"
export QML_XHR_ALLOW_FILE_READ=1
runner="${QMLTESTRUNNER:-$(command -v qmltestrunner || echo /usr/lib/qt6/bin/qmltestrunner)}"
"$runner" -input "${1:-$repo_dir/tests}"
