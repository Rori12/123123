# Live subtitles: перевод аудио в прямом эфире → титры RU / UK

Скрипт `live_subtitles.py` слушает звук (микрофон, системный звук или поток),
распознаёт речь (faster-whisper), переводит на русский и/или украинский и
показывает титры: в консоли, на веб-странице для OBS, в окне поверх всех окон
и в файлах `.srt`.

## Установка

```bash
pip install -r requirements.txt
```

При первом запуске модель Whisper скачивается с HuggingFace.
Для перевода по умолчанию нужен доступ к Google Translate.

## Запуск

```bash
# микрофон -> титры на русском и украинском, страница http://localhost:8765/
python live_subtitles.py

# только украинский, с окном поверх экрана
python live_subtitles.py --targets uk --overlay

# прямой эфир по ссылке (HLS / RTMP / m3u8), исходный язык английский
python live_subtitles.py --input "https://example.com/live.m3u8" --lang en

# системный звук: Linux (PulseAudio monitor), Windows (dshow), macOS (BlackHole)
python live_subtitles.py --input-format pulse --input default.monitor
python live_subtitles.py --input-format dshow --input "audio=Stereo Mix (Realtek Audio)"
python live_subtitles.py --input-format avfoundation --input ":BlackHole 2ch"

# проверка на файле в реальном времени + запись .srt
python live_subtitles.py --input talk.mp4 --realtime --srt-dir subs
```

### OBS
Источник → «Браузер» → URL `http://localhost:8765/`, ширина 1920, высота 1080.
Фон страницы прозрачный, украинская строка выделена жёлтым.

## Полезные параметры

| Параметр | По умолчанию | Описание |
|---|---|---|
| `--model` | `small` | `tiny`/`base` быстрее, `medium`/`large-v3` точнее (нужен GPU) |
| `--compute-device` | `auto` | `cuda` для NVIDIA (тогда `--compute-type float16`) |
| `--translator` | `google` | `argos` — офлайн, `none` — без перевода |
| `--silence-ms` | `500` | пауза, которая завершает фразу |
| `--max-seg` | `7` | максимальная длина фразы (с), меньше — меньше задержка |
| `--threshold` | `0.01` | порог громкости речи; поднять при шумном фоне |
| `--list-devices` | | список микрофонов (для `--device`) |

---

# Axiom: кисть «прикрепить блоки» (`axiom/attach_brush.lua`)

Скрипт для Script Brush мода Axiom. Находит выбранные блоки (например, листву)
и ставит в воздух рядом с ними другие блоки (например, кнопки), повёрнутые к
исходному блоку. Тип блока и сторона выбираются случайно. Меняется только воздух.

**Как пользоваться:** Axiom → Tools → Script Brush, вставить весь файл, выбрать
пресет в строке `PRESET = "leaf_buttons"` и рисовать.

**Готовые пресеты:**

| Пресет | Что делает |
|---|---|
| `leaf_buttons` | кнопки 6 видов дерева на листве, со всех сторон |
| `leaf_buttons_dark` | только тёмные кнопки (тёмный дуб, ель, мангр) |
| `stone_levers` | рычаги на боках камня и булыжника |
| `amethyst` | аметистовые друзы и почки на аметистовых блоках |
| `plank_ladders` | лестницы на боках досок |

**Настройки пресета:**
- `targets`: к каким блокам крепить. Тег пишется с `#` (`"#leaves"`), отдельный блок без него (`"oak_leaves"`).
- `place`: что ставить, случайно из списка. Это и есть выбор «цвета» кнопок, например `{ "cherry_button", "crimson_button" }`.
- `mode`: `button` для кнопок и рычагов (пол, потолок, стена), `facing_away` для блоков, которые смотрят от опоры (аметист, стержни края, лестницы), `facing_to` для блоков, которые смотрят на опору, `none` без поворота.
- `sides`: на какие стороны исходного блока можно ставить.
- `chance`: доля заполняемых мест, от 0 до 1.
- `seed`: другое число даёт другой случайный узор. При повторном проходе узор не меняется.

Свой пресет делается так: скопируйте любой блок в `PRESETS`, дайте ему имя и впишите это имя в `PRESET`.
