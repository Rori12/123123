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
