#!/usr/bin/env python3
"""Live audio translation with on-screen subtitles in Russian / Ukrainian.

Pipeline:  audio source -> speech segmentation (energy VAD) -> faster-whisper
           speech recognition -> translation (ru / uk) -> subtitle outputs.

Audio sources:
  --input mic                       default microphone (sounddevice)
  --input <URL or file>             stream/file decoded by PyAV (HLS, RTMP, mp4...)
  --input <device> --input-format F capture device via FFmpeg (pulse, dshow, avfoundation)

Subtitle outputs (any combination):
  console (always), web page for OBS "Browser source" (--web-port),
  always-on-top overlay window (--overlay), .srt files (--srt-dir).
"""

import argparse
import json
import queue
import sys
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import numpy as np

SAMPLE_RATE = 16000
FRAME_MS = 30
FRAME_LEN = SAMPLE_RATE * FRAME_MS // 1000
LANG_NAMES = {"ru": "Русский", "uk": "Українська"}


# --------------------------------------------------------------------------- audio

def mic_frames(stop, device=None):
    import sounddevice as sd

    q = queue.Queue()

    def callback(indata, _frames, _time, status):
        if status:
            print(f"[audio] {status}", file=sys.stderr)
        q.put(indata[:, 0].copy())

    with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="float32",
                        blocksize=FRAME_LEN, device=device, callback=callback):
        while not stop.is_set():
            try:
                yield q.get(timeout=0.5)
            except queue.Empty:
                continue


def av_frames(stop, url, fmt=None, realtime=False):
    import av

    container = av.open(url, format=fmt, timeout=10)
    resampler = av.AudioResampler(format="flt", layout="mono", rate=SAMPLE_RATE)
    start, sent = time.monotonic(), 0
    try:
        for frame in container.decode(audio=0):
            if stop.is_set():
                break
            for out in resampler.resample(frame):
                pcm = out.to_ndarray().reshape(-1).astype(np.float32)
                sent += len(pcm)
                yield pcm
            if realtime:  # pace files like a live stream
                ahead = sent / SAMPLE_RATE - (time.monotonic() - start)
                if ahead > 0:
                    time.sleep(ahead)
    finally:
        container.close()


class Segmenter:
    """Cuts the audio stream into phrases using frame energy and pauses."""

    def __init__(self, threshold, silence_ms, max_sec, min_sec=0.5):
        self.threshold = threshold
        self.silence_frames = silence_ms // FRAME_MS
        self.max_len = int(max_sec * SAMPLE_RATE)
        self.min_len = int(min_sec * SAMPLE_RATE)
        self.pending = np.zeros(0, dtype=np.float32)
        self.buf = []
        self.buf_len = 0
        self.quiet = 0
        self.preroll = deque(maxlen=10)  # keep ~300 ms before speech onset
        self.t = 0.0   # stream time of the current frame
        self.t0 = 0.0  # stream time of the segment start

    def feed(self, pcm):
        self.pending = np.concatenate([self.pending, pcm])
        while len(self.pending) >= FRAME_LEN:
            frame, self.pending = self.pending[:FRAME_LEN], self.pending[FRAME_LEN:]
            self.t += FRAME_MS / 1000
            seg = self._frame(frame)
            if seg is not None:
                yield seg

    def _frame(self, frame):
        loud = float(np.sqrt(np.mean(frame ** 2))) > self.threshold
        if not self.buf:
            if loud:
                self.buf = list(self.preroll) + [frame]
                self.buf_len = sum(len(f) for f in self.buf)
                self.t0 = self.t - len(self.buf) * FRAME_MS / 1000
                self.quiet = 0
            else:
                self.preroll.append(frame)
            return None
        self.buf.append(frame)
        self.buf_len += len(frame)
        self.quiet = 0 if loud else self.quiet + 1
        if self.quiet >= self.silence_frames or self.buf_len >= self.max_len:
            return self.flush()
        return None

    def flush(self):
        if not self.buf:
            return None
        audio = np.concatenate(self.buf)
        start, end = self.t0, self.t
        self.buf, self.buf_len, self.quiet = [], 0, 0
        self.preroll.clear()
        if len(audio) < self.min_len:
            return None
        return start, end, audio


# ------------------------------------------------------------------ ASR / MT

class Transcriber:
    def __init__(self, model, device, compute_type, language):
        from faster_whisper import WhisperModel

        print(f"[asr] loading model '{model}' on {device} ...", file=sys.stderr)
        self.model = WhisperModel(model, device=device, compute_type=compute_type)
        self.language = language

    def __call__(self, audio):
        segments, info = self.model.transcribe(
            audio, language=self.language, beam_size=1, vad_filter=True,
            condition_on_previous_text=False)
        text = " ".join(s.text.strip() for s in segments).strip()
        return text, info.language


class Translator:
    def __init__(self, backend, targets):
        self.backend = backend
        self.targets = targets
        self._cache = {}

    def __call__(self, text, src):
        out = {}
        for tgt in self.targets:
            if src == tgt or self.backend == "none":
                out[tgt] = text
                continue
            try:
                out[tgt] = self._translate(text, src, tgt)
            except Exception as e:  # keep the stream alive on network errors
                print(f"[mt] {self.backend} {src}->{tgt} failed: {e}", file=sys.stderr)
                out[tgt] = text
        return out

    def _translate(self, text, src, tgt):
        if self.backend == "google":
            from deep_translator import GoogleTranslator

            key = (src, tgt)
            if key not in self._cache:
                self._cache[key] = GoogleTranslator(source=src or "auto", target=tgt)
            return self._cache[key].translate(text)
        if self.backend == "argos":
            import argostranslate.translate as at

            return at.translate(text, src, tgt)
        raise ValueError(self.backend)


# --------------------------------------------------------------------- outputs

class SubtitleBoard:
    """Holds the latest captions; every output reads from here."""

    def __init__(self, targets, history=2):
        self.targets = targets
        self.lines = deque(maxlen=history)
        self.version = 0
        self.lock = threading.Lock()
        self.listeners = []

    def push(self, item):
        with self.lock:
            self.lines.append(item)
            self.version += 1
        for fn in self.listeners:
            fn(item)

    def snapshot(self):
        with self.lock:
            return {"version": self.version, "lines": list(self.lines)}


class SrtWriter:
    def __init__(self, directory, targets):
        directory = Path(directory)
        directory.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        self.files = {t: open(directory / f"subs-{stamp}.{t}.srt", "w", encoding="utf-8")
                      for t in targets}
        self.n = 0

    @staticmethod
    def _ts(sec):
        ms = int(round(sec * 1000))
        h, ms = divmod(ms, 3600000)
        m, ms = divmod(ms, 60000)
        s, ms = divmod(ms, 1000)
        return f"{h:02}:{m:02}:{s:02},{ms:03}"

    def __call__(self, item):
        self.n += 1
        for lang, f in self.files.items():
            f.write(f"{self.n}\n{self._ts(item['start'])} --> {self._ts(item['end'])}\n"
                    f"{item['text'][lang]}\n\n")
            f.flush()


PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>Live subtitles</title>
<style>
 html,body{margin:0;background:transparent;font-family:Arial,sans-serif}
 #box{position:fixed;left:0;right:0;bottom:4vh;text-align:center}
 .line{display:inline-block;margin:.15em auto;padding:.15em .5em;border-radius:.3em;
       background:rgba(0,0,0,.65);color:#fff;font-size:__SIZE__px;line-height:1.25;
       text-shadow:0 0 3px #000;max-width:92vw}
 .lang-uk{color:#ffe46b}
 .old{opacity:.55}
</style></head><body><div id="box"></div><script>
let v=-1;
async function tick(){
 try{const r=await fetch('/api/subs');const d=await r.json();
  if(d.version!==v){v=d.version;const box=document.getElementById('box');box.innerHTML='';
   d.lines.forEach((l,i)=>{for(const [lang,t] of Object.entries(l.text)){
     const div=document.createElement('div');const s=document.createElement('span');
     s.className='line lang-'+lang+(i<d.lines.length-1?' old':'');s.textContent=t;
     div.appendChild(s);box.appendChild(div);}});}
 }catch(e){}
 setTimeout(tick,300);}
tick();
</script></body></html>"""


def start_web(board, port, font_size):
    page = PAGE.replace("__SIZE__", str(font_size)).encode()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith("/api/subs"):
                body = json.dumps(board.snapshot(), ensure_ascii=False).encode()
                ctype = "application/json; charset=utf-8"
            elif self.path in ("/", "/index.html"):
                body, ctype = page, "text/html; charset=utf-8"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    print(f"[web] subtitles page: http://localhost:{port}/  (OBS -> Browser source)",
          file=sys.stderr)
    return server


def run_overlay(board, font_size, stop):
    """Always-on-top translucent window at the bottom of the screen (main thread)."""
    import tkinter as tk

    root = tk.Tk()
    root.title("Live subtitles")
    root.attributes("-topmost", True)
    try:
        root.attributes("-alpha", 0.85)
    except tk.TclError:
        pass
    w, h = root.winfo_screenwidth(), font_size * 6
    root.geometry(f"{w}x{h}+0+{root.winfo_screenheight() - h - 60}")
    root.configure(bg="black")
    labels = {}
    for lang in board.targets:
        lbl = tk.Label(root, text="", fg="#ffe46b" if lang == "uk" else "white", bg="black",
                       font=("Arial", font_size, "bold"), wraplength=w - 40, justify="center")
        lbl.pack(expand=True, fill="both")
        labels[lang] = lbl
    root.bind("<Escape>", lambda _e: root.destroy())
    seen = [-1]

    def refresh():
        snap = board.snapshot()
        if snap["version"] != seen[0] and snap["lines"]:
            seen[0] = snap["version"]
            for lang, lbl in labels.items():
                lbl.config(text=snap["lines"][-1]["text"][lang])
        if stop.is_set():
            root.destroy()
            return
        root.after(200, refresh)

    refresh()
    root.mainloop()
    stop.set()


# ----------------------------------------------------------------------- main

def pipeline(args, board, stop, transcriber, translator):
    seg = Segmenter(args.threshold, args.silence_ms, args.max_seg)
    jobs = queue.Queue(maxsize=8)

    def worker():
        while True:
            job = jobs.get()
            if job is None:
                return
            start, end, audio = job
            t = time.monotonic()
            text, src = transcriber(audio)
            if not text:
                continue
            item = {"start": start, "end": end, "src": src, "orig": text,
                    "text": translator(text, src)}
            lag = time.monotonic() - t
            print(f"\n[{SrtWriter._ts(start)}] ({src}) {text}   [{lag:.1f}s]")
            for lang in board.targets:
                print(f"  {lang}: {item['text'][lang]}")
            board.push(item)

    wt = threading.Thread(target=worker, daemon=True)
    wt.start()

    if args.input == "mic":
        frames = mic_frames(stop, args.device)
    else:
        frames = av_frames(stop, args.input, args.input_format, args.realtime)

    def put(job):
        try:
            jobs.put_nowait(job)
        except queue.Full:  # recognition can't keep up: drop instead of lagging
            print("[asr] too slow, segment dropped (try smaller --model)", file=sys.stderr)

    try:
        for pcm in frames:
            for job in seg.feed(pcm):
                put(job)
    finally:
        last = seg.flush()
        if last:
            put(last)
        jobs.put(None)
        wt.join()
        stop.set()


def parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--input", default="mic", help="'mic', URL, file or FFmpeg device")
    p.add_argument("--input-format", help="FFmpeg input format, e.g. pulse, dshow, avfoundation")
    p.add_argument("--device", help="sounddevice input device (name or index) for --input mic")
    p.add_argument("--realtime", action="store_true", help="play files at real speed")
    p.add_argument("--lang", default=None, help="source language (en, de, ...); auto by default")
    p.add_argument("--targets", default="ru,uk", help="subtitle languages: ru, uk or ru,uk")
    p.add_argument("--translator", default="google", choices=["google", "argos", "none"])
    p.add_argument("--model", default="small", help="whisper model: tiny/base/small/medium/large-v3")
    p.add_argument("--compute-device", default="auto", help="cpu, cuda or auto")
    p.add_argument("--compute-type", default="int8", help="int8, float16, int8_float16 ...")
    p.add_argument("--threshold", type=float, default=0.01, help="speech energy threshold (RMS)")
    p.add_argument("--silence-ms", type=int, default=500, help="pause that ends a phrase")
    p.add_argument("--max-seg", type=float, default=7.0, help="max phrase length, seconds")
    p.add_argument("--web-port", type=int, default=8765, help="0 to disable the web page")
    p.add_argument("--overlay", action="store_true", help="show always-on-top subtitle window")
    p.add_argument("--font-size", type=int, default=36)
    p.add_argument("--srt-dir", help="also write .srt files into this directory")
    p.add_argument("--list-devices", action="store_true", help="list microphones and exit")
    args = p.parse_args(argv)
    args.targets = [t.strip() for t in args.targets.split(",") if t.strip()]
    bad = [t for t in args.targets if t not in LANG_NAMES]
    if bad:
        p.error(f"unsupported target language(s): {bad}; use ru and/or uk")
    return args


def main(argv=None):
    args = parse_args(argv)
    if args.list_devices:
        import sounddevice as sd

        print(sd.query_devices())
        return

    board = SubtitleBoard(args.targets)
    if args.srt_dir:
        board.listeners.append(SrtWriter(args.srt_dir, args.targets))
    if args.web_port:
        start_web(board, args.web_port, args.font_size)

    transcriber = Transcriber(args.model, args.compute_device, args.compute_type, args.lang)
    translator = Translator(args.translator, args.targets)
    stop = threading.Event()

    def run():
        try:
            pipeline(args, board, stop, transcriber, translator)
        except Exception as e:
            print(f"[error] {e}", file=sys.stderr)
            stop.set()

    t = threading.Thread(target=run, daemon=True)
    t.start()
    print(f"[run] {args.input} -> {', '.join(LANG_NAMES[x] for x in args.targets)}. "
          "Ctrl+C to stop.", file=sys.stderr)
    try:
        if args.overlay:
            run_overlay(board, args.font_size, stop)
        while t.is_alive():
            t.join(0.5)
    except KeyboardInterrupt:
        stop.set()
        t.join(5)


if __name__ == "__main__":
    main()
