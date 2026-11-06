#!/usr/bin/env bash
# Сборка стенда лабораторной работы на основе ggerganov/kbd-audio.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Запускать нужно через sudo: sudo ./install.sh" >&2
  exit 1
fi

KBD_URL="https://github.com/ggerganov/kbd-audio.git"
SRC="/opt/kbd-audio/src"
BUILD="$SRC/build"
DATA_DIR="/usr/local/share/kbd-audio/data"
PREFIX_BIN="/usr/local/bin"

echo "==> [1/5] Проверка окружения"
for c in git cmake make gcc; do
  command -v "$c" >/dev/null || { echo "Не найден $c" >&2; exit 1; }
done

echo "==> [2/5] Установка системных зависимостей"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
    git cmake build-essential libsdl2-dev libfftw3-dev \
    pkg-config alsa-utils

echo "==> [3/5] Клонирование kbd-audio в $SRC"
mkdir -p "$(dirname "$SRC")"
if [ ! -d "$SRC/.git" ]; then
    git clone "$KBD_URL" "$SRC"
else
    echo "    Уже клонирован — пропускаем"
fi

echo "==> [4/5] Сборка"
cd "$SRC"
git submodule update --init
mkdir -p "$BUILD"
cd "$BUILD"
cmake ..
make -j"$(nproc)"

echo "==> [5/5] Установка"
for bin in record record-full keytap keytap2 keytap2-gui keytap3 \
           view view-gui view-full view-full-gui; do
    if [ -x "$BUILD/$bin" ]; then
        install -m 0755 "$BUILD/$bin" "$PREFIX_BIN/$bin"
    fi
done

mkdir -p "$DATA_DIR"
cp -r "$SRC/data/." "$DATA_DIR/"

cat <<EOF

Готово.
  Бинарники:  $PREFIX_BIN/{record,record-full,keytap,keytap3,view-gui,view-full-gui}
  Данные:     $DATA_DIR

Проверьте, что $PREFIX_BIN в \$PATH:
  echo \$PATH

Проверка:
  keytap3 --help 2>/dev/null || true
  ls $DATA_DIR
EOF