#!/usr/bin/env bash
# Проверка правильности установки стенда.
# Запуск: ./check.sh
set -u

fail=0
warn=0

check_bin() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "  [ OK ]  %-15s -> %s\n" "$1" "$(command -v "$1")"
    else
        printf "  [FAIL]  %-15s не найден в PATH\n" "$1"
        fail=$((fail + 1))
    fi
}

for b in record record-full keytap keytap2 keytap3 view-gui view-full-gui; do
    check_bin "$b"
done

if [ -d "/usr/local/share/kbd-audio/data" ]; then
    n=$(find /usr/local/share/kbd-audio/data -type f 2>/dev/null | wc -l)
    if [ "$n" -gt 0 ]; then
        printf "  [ OK ]  /usr/local/share/kbd-audio/data (%d файлов)\n" "$n"
    else
        printf "  [FAIL]  /usr/local/share/kbd-audio/data пуст\n"
        fail=$((fail + 1))
    fi
else
    printf "  [FAIL]  каталог /usr/local/share/kbd-audio/data отсутствует\n"
    fail=$((fail + 1))
fi

for p in git cmake make gcc pkg-config; do
    if command -v "$p" >/dev/null 2>&1; then
        printf "  [ OK ]  %s\n" "$p"
    else
        printf "  [FAIL]  %s не найден\n" "$p"
        fail=$((fail + 1))
    fi
done

if pkg-config --exists sdl2 2>/dev/null; then
    printf "  [ OK ]  SDL2 %s\n" "$(pkg-config --modversion sdl2)"
else
    printf "  [FAIL]  SDL2 не найден (пакет libsdl2-dev)\n"
    fail=$((fail + 1))
fi

if command -v arecord >/dev/null 2>&1; then
    if arecord -l 2>/dev/null | grep -q "card"; then
        printf "  [ OK ]  микрофон виден\n"
    else
        printf "  [WARN]  микрофон не обнаружен — проверьте проброс аудио в ВМ\n"
        warn=$((warn + 1))
    fi
else
    printf "  [FAIL]  arecord не найден (пакет alsa-utils)\n"
    fail=$((fail + 1))
fi


for d in "$HOME/kbd-lab/data" "$HOME/kbd-lab/results"; do
    if [ -d "$d" ]; then
        printf "  [ OK ]  %s\n" "$d"
    else
        printf "  [WARN]  %s отсутствует (создайте: mkdir -p %s)\n" "$d" "$d"
        warn=$((warn + 1))
    fi
done

echo
if [ "$fail" -ne 0 ]; then
    echo "Ошибок: $fail. Переустановите: sudo ./install.sh"
    exit 1
fi
if [ "$warn" -ne 0 ]; then
    echo "Предупреждений: $warn. Стенд работает, но проверьте замечания выше."
    exit 0
fi
echo "Все проверки пройдены."