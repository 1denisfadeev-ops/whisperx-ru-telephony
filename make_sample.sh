#!/bin/zsh
# Собирает синтетический тестовый звонок на русском, чтобы проверять ASR
# без реальных записей разговоров — в них персональные данные.
#
# В macOS один русский голос (Milena), поэтому второго говорящего делаем
# сдвигом тона. Итог прогоняем через полосу 300–3400 Гц и 8 кГц: так звучит
# телефония, и оценка качества на нём честнее, чем на студийной записи.
set -e

cd "$(dirname "$0")"
OUT=audio
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

OPERATOR=(
  "Добрый день, сервисный центр, меня зовут Ольга, чем могу помочь?"
  "Подскажите номер договора и когда заметили неисправность?"
  "Вижу вашу заявку. Скорее всего это блок питания, нужна диагностика."
  "Мастер может подъехать в четверг с двух до шести, вам удобно?"
  "Хорошо, я оформила заявку, мастер позвонит за час до выезда."
)
CALLER=(
  "Здравствуйте, у меня не включается оборудование после грозы."
  "Договор восемьсот сорок два, перестало работать вчера вечером."
  "А сколько времени займёт ремонт? Нам важно запуститься на этой неделе."
  "В четверг неудобно, давайте лучше в пятницу утром."
  "Да, спасибо, буду ждать."
)

i=1
: > "$TMP/list.txt"
while [ $i -le ${#OPERATOR[@]} ]; do
  say -v Milena -r 190 -o "$TMP/o$i.aiff" "${OPERATOR[$i]}"
  ffmpeg -loglevel error -y -i "$TMP/o$i.aiff" -ar 16000 -ac 1 "$TMP/o$i.wav"

  say -v Milena -r 175 -o "$TMP/c$i.aiff" "${CALLER[$i]}"
  # сдвиг тона вниз — имитация второго говорящего
  ffmpeg -loglevel error -y -i "$TMP/c$i.aiff" \
    -af "asetrate=22050*0.82,atempo=1.22,aresample=16000" -ar 16000 -ac 1 "$TMP/c$i.wav"

  echo "file '$TMP/o$i.wav'" >> "$TMP/list.txt"
  echo "file '$TMP/c$i.wav'" >> "$TMP/list.txt"
  i=$((i + 1))
done

ffmpeg -loglevel error -y -f concat -safe 0 -i "$TMP/list.txt" -c copy "$TMP/joined.wav"

# полоса телефонии + 8 кГц, обратно в 16 кГц (ASR ждёт 16к на входе)
ffmpeg -loglevel error -y -i "$TMP/joined.wav" \
  -af "highpass=f=300,lowpass=f=3400,aresample=8000,aresample=16000" \
  -ar 16000 -ac 1 "$OUT/zvonok.wav"

echo "готово: $OUT/zvonok.wav"
ffprobe -v error -show_entries format=duration -of default=nw=1 "$OUT/zvonok.wav"
