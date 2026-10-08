#!/usr/bin/env bash
# Собирает hermes-agent.zip (исходники Hermes с .git) и Hermes-Loodsen-Windows.zip для раздачи.
#   ./build-bundle.sh [ветка-или-тег]   (по умолчанию main)
set -euo pipefail
ref="${1:-main}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Как install.ps1: blobless-клон с тегами — по ближайшему тегу Hermes определяет свою версию.
git clone -q --filter=blob:none --branch "$ref" https://github.com/NousResearch/hermes-agent.git "$work/hermes-agent"
git -C "$work/hermes-agent" config core.autocrlf false
git -C "$work/hermes-agent" config core.filemode false
git -C "$work/hermes-agent" config --unset core.precomposeunicode || true
find "$work/hermes-agent" -name .DS_Store -delete

rm -f "$here/hermes-agent.zip"
(cd "$work" && zip -r -q -X "$here/hermes-agent.zip" hermes-agent)

dist="$work/dist/hermes-loodsen-windows"
mkdir -p "$dist"
cp "$here/Install-Hermes-Loodsen.cmd" "$here/Uninstall-Hermes-Loodsen.cmd" "$here/README.txt" "$here/hermes-agent.zip" "$dist/"
rm -f "$here/Hermes-Loodsen-Windows.zip"
(cd "$work/dist" && zip -q -X -0 -r "$here/Hermes-Loodsen-Windows.zip" hermes-loodsen-windows)
echo "Hermes $(git -C "$work/hermes-agent" describe --tags) -> $here/Hermes-Loodsen-Windows.zip"
