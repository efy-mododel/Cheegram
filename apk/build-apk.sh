#!/usr/bin/env bash
# Собрать полноценный APK Cheegram (Telegram 13.2.2) через Docker и положить
# готовый файл в папку apk/.
#
# Использование:
#   ./apk/build-apk.sh              # standalone APK (универсальный, для прямой установки)
#   ./apk/build-apk.sh release      # обычный release APK (org.telegram.messenger)
#   ./apk/build-apk.sh all          # оба варианта + AAB
set -euo pipefail

cd "$(dirname "$0")/.."

VARIANT="${1:-standalone}"
VERSION_NAME="$(grep -E '^APP_VERSION_NAME=' gradle.properties | cut -d= -f2)"
VERSION_CODE="$(grep -E '^APP_VERSION_CODE=' gradle.properties | cut -d= -f2)"

echo "==> Cheegram ${VERSION_NAME} (${VERSION_CODE}), variant: ${VARIANT}"

if ! command -v docker >/dev/null 2>&1; then
  echo "ОШИБКА: Docker не найден. Установите Docker или соберите APK в Android Studio" >&2
  echo "        (см. Compilation Guide в README.md). Либо скачайте готовый APK:" >&2
  echo "        ./apk/download-apk.sh" >&2
  exit 1
fi

echo "==> Собираю Docker-образ (SDK 36, NDK 27.2, JDK 17)..."
docker build -t cheegram-builder .

echo "==> Запускаю сборку внутри контейнера..."
# Внутри контейнера исходники монтируются в /home/source, Gradle работает в /home/gradle.
# Собираем явно и копируем APK с понятными именами, чтобы standalone и release
# не затирали друг друга (в Dockerfile оба пишутся как app.apk).
docker run --rm \
  -v "$PWD:/home/source" \
  cheegram-builder \
  bash -c '
    set -e
    mkdir -p /home/source/TMessagesProj/build/outputs/apk /home/gradle
    tar -C /home/source \
      --exclude=./.git --exclude=.cxx --exclude=build --exclude=.gradle --exclude=./local.properties \
      -cf - . | tar -C /home/gradle -xf -
    cd /home/gradle
    case "'"$VARIANT"'" in
      standalone)
        gradle --parallel :TMessagesProj_AppStandalone:assembleAfatStandalone --stacktrace
        ;;
      release)
        gradle --parallel :TMessagesProj_App:assembleAfatRelease --stacktrace
        ;;
      all)
        gradle --parallel \
          :TMessagesProj_AppStandalone:assembleAfatStandalone \
          :TMessagesProj_App:assembleAfatRelease \
          :TMessagesProj_App:bundleAfatRelease --stacktrace
        ;;
      *)
        echo "Неизвестный вариант: $VARIANT (standalone|release|all)" >&2; exit 1
        ;;
    esac
    mkdir -p /home/source/apk/.build-out
    find /home/gradle -path "*build/outputs/apk*" -name "*.apk" -exec cp -v {} /home/source/apk/.build-out/ \;
    find /home/gradle -path "*build/outputs/bundle*" -name "*.aab" -exec cp -v {} /home/source/apk/.build-out/ \; || true
  '

OUT_DIR="apk/.build-out"
mkdir -p apk

copy_apk() {
  local src="$1" dst="$2"
  if [ -f "$src" ]; then
    cp -v "$src" "apk/$dst"
    echo "==> Готово: apk/$dst"
  fi
}

# Gradle кладёт результат как app.apk в подпапках flavor/buildType.
# Различаем варианты по пути внутри .build-out невозможно (файлы плоские),
# поэтому ищем исходники заново в смонтированном дереве через find по модулям.
# Проще: пересобираем имена по факту наличия файлов в .build-out.
APKS=( "$OUT_DIR"/*.apk )
if [ "${#APKS[@]}" -eq 0 ] || [ ! -f "${APKS[0]}" ]; then
  echo "ОШИБКА: APK не найден в $OUT_DIR" >&2
  ls -la "$OUT_DIR" || true
  exit 1
fi

# Если собран один APK — это запрошенный вариант. Если несколько (all) —
# раздаём имена по порядку: standalone первым не гарантируется, поэтому
# дополнительно смотрим размер/путь нельзя; просто нумеруем и печатаем список.
if [ "${#APKS[@]}" -eq 1 ]; then
  case "$VARIANT" in
    standalone) copy_apk "${APKS[0]}" "Cheegram-${VERSION_NAME}-${VERSION_CODE}-standalone.apk" ;;
    release)    copy_apk "${APKS[0]}" "Cheegram-${VERSION_NAME}-${VERSION_CODE}-release.apk" ;;
    *)          copy_apk "${APKS[0]}" "Cheegram-${VERSION_NAME}-${VERSION_CODE}.apk" ;;
  esac
else
  i=1
  for f in "${APKS[@]}"; do
    copy_apk "$f" "Cheegram-${VERSION_NAME}-${VERSION_CODE}-$i.apk"
    i=$((i+1))
  done
fi

for aab in "$OUT_DIR"/*.aab; do
  [ -f "$aab" ] && copy_apk "$aab" "Cheegram-${VERSION_NAME}-${VERSION_CODE}.aab"
done

rm -rf "$OUT_DIR"

echo "==> Контрольные суммы:"
( cd apk && sha256sum *.apk *.aab 2>/dev/null | tee CHECKSUMS.txt )

echo "==> APK лежит в папке apk/:"
ls -lh apk/
