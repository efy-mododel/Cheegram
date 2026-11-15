#!/usr/bin/env bash
# Скачать готовый APK Cheegram из GitHub Releases в папку apk/.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "ОШИБКА: GitHub CLI (gh) не найден. Скачайте APK вручную:" >&2
  echo "  https://github.com/efy-mododel/Cheegram/releases" >&2
  exit 1
fi

mkdir -p apk

echo "==> Скачиваю последний APK в apk/ ..."
# gh скачает все .apk-ассеты последнего релиза в текущую папку.
gh release download --pattern '*.apk' --dir apk --clobber

echo "==> Готово:"
ls -lh apk/*.apk

( cd apk && sha256sum *.apk | tee CHECKSUMS.txt )
