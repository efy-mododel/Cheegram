# Cheegram — готовый APK

Здесь лежит собранный APK мессенджера **Cheegram** (форк Telegram for Android).

- Версия: **13.2.2** (`APP_VERSION_CODE=7303`, см. `gradle.properties`)
- Пакет: `org.telegram.messenger` (standalone-сборка: `org.telegram.messenger.web`)
- Архитектуры: `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` (один универсальный APK, `afat`)
- Min SDK: 23, Target/Compile SDK: 36, NDK: 27.2.12479018

## Как получить APK

### Вариант 1 — скачать готовый APK из GitHub Releases (быстрее всего)

```bash
./apk/download-apk.sh
# APK появится здесь: apk/Cheegram-13.2.2-7303-standalone.apk
```

Или вручную: вкладка **Releases** этого репозитория → скачать `.apk`.

### Вариант 2 — собрать APK локально через Docker (одна команда)

Нужен только Docker (Android SDK/NDK/JDK ставятся внутри образа из `Dockerfile`):

```bash
./apk/build-apk.sh
```

Скрипт соберёт образ, запустит Gradle (`:TMessagesProj_AppStandalone:assembleAfatStandalone`)
и положит готовый APK сюда, в папку `apk/`.

### Вариант 3 — собрать через GitHub Actions

Вкладка **Actions → Build APK → Run workflow**. После сборки APK будет доступен
как artifact запуска и как asset в GitHub Release.

## Установка на телефон

1. Скопируйте APK из этой папки на телефон (или скачайте напрямую на телефон).
2. Разрешите установку из неизвестных источников для браузера/файлового менеджера.
3. Установите APK и войдите по номеру телефона.

## Почему сам APK не хранится в git

APK весит десятки мегабайт и является бинарным артефактом сборки. Его нельзя
надёжно хранить в git-истории (лимит GitHub — 100 МБ на файл, а репозиторий
раздувается навсегда). Поэтому:

- папка `apk/` хранится в репозитории вместе со скриптами,
- сам `.apk` скачивается из **GitHub Releases** (`download-apk.sh`) или
  собирается локально (`build-apk.sh`) и кладётся сюда же — но не коммитится
  (см. `.gitignore`: `apk/*.apk`).

После сборки/скачивания рядом с APK можно положить контрольную сумму:

```bash
cd apk && sha256sum *.apk > CHECKSUMS.txt
```

## Примечание про `api_id`

В `TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java` сейчас стоят
официальные `APP_ID`/`APP_HASH` Telegram — для личного использования APK
запускается сразу. Для публикации в сторах получите собственный `api_id`
на https://core.telegram.org/api/obtaining_api_id и замените значения в `BuildVars.java`,
а также свой `release.keystore` и `google-services.json` (см. Compilation Guide в корневом `README.md`).
