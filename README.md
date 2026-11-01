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

Скрипт для Script Brush мода Axiom. Находит выбранные блоки (по умолчанию
листву дуба, берёзы и ели) и ставит в воздух рядом с ними другие блоки (по
умолчанию кнопки шести видов дерева), повёрнутые к исходному блоку. Меняется
только воздух. Скрипт использует только функции из официальной документации Axiom.

**Как пользоваться:** Axiom → Script Brush → Tool Options, вставить весь файл.
Настройки появятся в том же окне:

| Настройка | Что делает |
|---|---|
| Target 1-3 | к каким блокам крепить |
| Block 1-6 | какие блоки ставить (выбор цвета кнопок), выбираются случайно |
| Blocks to use | сколько первых блоков из Block 1-6 использовать |
| Mode | 1 кнопки и рычаги (пол, потолок, стена), 2 блоки с `facing` (аметист, лестница), 3 без поворота |
| Density | доля заполняемых мест, от 0 до 1 |
| Pattern seed | другое число даёт другой случайный узор |
| Place on top / below / on sides | на какие стороны цели ставить |
| Face the target | развернуть блок к цели, а не от неё |
| Facing may be up or down | выключить для блоков без направления вверх/вниз (лестница) |

Названия настроек английские и без скобок: Axiom разбирает `$...$` по скобкам,
скобки в названии его ломают.

**Если блоки не ставятся**, по очереди попробуйте тесты:
1. `axiom/test_1_place_anything.lua`: должен залить всё красной шерстью.
2. `axiom/test_2_trigger_on_leaves.lua`: красная шерсть над дубовой листвой.
