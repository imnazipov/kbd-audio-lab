#!/usr/bin/env bash
# Сборка и установка стенда лабораторной работы.

set -euo pipefail

trap 'echo; echo "ОШИБКА на строке $LINENO: установка прервана." >&2; \
      echo "Исправьте причину и запустите снова: sudo ./install.sh" >&2' ERR

if [ "$EUID" -ne 0 ]; then
  echo "Запускать нужно через sudo: sudo ./install.sh" >&2
  exit 1
fi

KBD_URL="https://github.com/ggerganov/kbd-audio.git"
SRC="/opt/kbd-audio/src"
BUILD="$SRC/build"
DATA_DIR="/usr/local/share/kbd-audio/data"
PREFIX_BIN="/usr/local/bin"

step() { echo; echo "==> $*"; }

step "[1/6] Установка системных зависимостей"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    git cmake build-essential libsdl2-dev libfftw3-dev \
    pkg-config alsa-utils

step "[2/6] Проверка инструментов сборки"
missing=()
for c in git cmake make gcc; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if ! pkg-config --exists sdl2 2>/dev/null; then
    missing+=("libsdl2-dev")
fi
if [ "${#missing[@]}" -ne 0 ]; then
    echo "Не найдены после установки: ${missing[*]}" >&2
    echo "Проверьте apt-источники и повторите." >&2
    exit 1
fi
echo "  все инструменты на месте"

step "[3/6] Клонирование kbd-audio в $SRC"
mkdir -p "$(dirname "$SRC")"
if [ ! -d "$SRC/.git" ]; then
    git clone "$KBD_URL" "$SRC"
else
    echo "  уже клонирован — пропускаем"
fi

step "[4/6] Сборка"
cd "$SRC"
# Подмодули есть не во всех версиях репозитория — не считаем их отсутствие ошибкой
git submodule update --init || echo "  подмодулей нет — пропускаем"
mkdir -p "$BUILD"
cd "$BUILD"
cmake ..
make -j"$(nproc)"

step "[5/6] Установка бинарников в $PREFIX_BIN"
installed=0
for bin in record record-full keytap keytap2 keytap2-gui keytap3 \
           view view-gui view-full view-full-gui; do
    if [ -x "$BUILD/$bin" ]; then
        install -m 0755 "$BUILD/$bin" "$PREFIX_BIN/$bin"
        installed=$((installed + 1))
    fi
done
echo "  установлено бинарников: $installed"
if [ "$installed" -eq 0 ]; then
    echo "Ни один бинарник не собран — проверьте вывод make выше." >&2
    exit 1
fi

step "[6/6] Установка данных n-грамм в $DATA_DIR"
if [ -d "$SRC/data" ] && [ -n "$(ls -A "$SRC/data" 2>/dev/null)" ]; then
    mkdir -p "$DATA_DIR"
    cp -r "$SRC/data/." "$DATA_DIR/"
    echo "  файлов скопировано: $(find "$DATA_DIR" -type f | wc -l)"
else
    echo "  ВНИМАНИЕ: $SRC/data пуст или отсутствует." >&2
    echo "  keytap3 без n-грамм работать не будет." >&2
    echo "  Проверьте структуру репозитория kbd-audio." >&2
fi

step "Готово"
cat <<EOF
  Бинарники:  $PREFIX_BIN/{record,record-full,keytap,keytap3,view-gui,view-full-gui}
  Данные:     $DATA_DIR

Проверьте, что $PREFIX_BIN в \$PATH:
  echo \$PATH

Проверка установки:
  ./check.sh
EOF