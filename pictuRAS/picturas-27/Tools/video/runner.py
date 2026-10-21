"""Execução de processos FFmpeg com progresso, cancelamento, limite de tempo e de memória.

Requisitos: REQ-VID-STATUS-001 (progresso), REQ-VID-STATUS-003 (cancelamento),
REQ-VID-STATUS-005 (limite de memória), REQ-VID-SPD-006 (limite de tempo).
"""
import os
import re
import subprocess
import threading
import time


class JobError(Exception):
    """Falha de um trabalho, com um código estável que o serviço projects entende."""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


# Códigos de erro partilhados com projects/utils/videoErrors.js
CANCELLED = "cancelled"
TIMEOUT = "timeout"
OUT_OF_MEMORY = "out_of_memory"
CORRUPT_INPUT = "corrupt_input"
INVALID_PARAMS = "invalid_params"
FONT_RENDER = "font_render"
PROCESSING_ERROR = "processing_error"

_OOM_PATTERNS = re.compile(r"Cannot allocate memory|out of memory|ENOMEM|std::bad_alloc", re.I)
_CORRUPT_PATTERNS = re.compile(
    r"Invalid data found when processing input|corrupt|error while decoding|"
    r"moov atom not found|Invalid NAL unit|non-existing PPS",
    re.I,
)


_PAGE = os.sysconf("SC_PAGE_SIZE") if hasattr(os, "sysconf") else 4096


def rss_mb(pid):
    """Memória residente de um processo (Linux), em MB; None se não disponível."""
    try:
        with open(f"/proc/{pid}/statm") as fh:
            return int(fh.read().split()[1]) * _PAGE / (1024 * 1024)
    except (OSError, ValueError, IndexError):
        return None


class MemoryGuard:
    """Falha rápida por memória (REQ-VID-STATUS-005, DQ-006).

    Mede a memória residente dos processos FFmpeg e termina-os quando excedem o limite.
    Um limite com RLIMIT_AS não serve: com pouca memória o FFmpeg/libx264 pode bloquear
    em vez de terminar, e o trabalho só acabaria pelo tempo máximo.
    """

    def __init__(self, mem_mb):
        self.mem_mb = mem_mb

    def exceeded(self, *procs):
        if not self.mem_mb:
            return False
        total = sum(rss_mb(p.pid) or 0 for p in procs if p.poll() is None)
        return total > self.mem_mb


class CancelCheck:
    """Verifica o pedido de cancelamento (ficheiro CANCEL na pasta do trabalho) e o limite de tempo."""

    def __init__(self, cancel_file=None, timeout_sec=None):
        self.cancel_file = cancel_file
        self.deadline = time.monotonic() + timeout_sec if timeout_sec else None
        self.timeout_sec = timeout_sec

    def cancelled(self):
        return bool(self.cancel_file) and os.path.exists(self.cancel_file)

    def timed_out(self):
        return self.deadline is not None and time.monotonic() > self.deadline

    def raise_if_needed(self):
        if self.cancelled():
            raise JobError(CANCELLED, "Trabalho cancelado pelo utilizador")
        if self.timed_out():
            raise JobError(TIMEOUT, f"Tempo máximo de processamento excedido ({self.timeout_sec:g} s)")


def classify_failure(returncode, stderr_tail):
    if returncode in (-9, 137) or _OOM_PATTERNS.search(stderr_tail or ""):
        return JobError(OUT_OF_MEMORY, "Falha de processamento por falta de recursos no nó de renderização")
    if _CORRUPT_PATTERNS.search(stderr_tail or ""):
        return JobError(CORRUPT_INPUT, "Não foi possível processar o vídeo: ficheiro corrompido ou fotogramas inválidos")
    last = (stderr_tail or "").strip().splitlines()[-3:]
    return JobError(PROCESSING_ERROR, "Erro do FFmpeg: " + " | ".join(last))


def _close(*procs):
    for p in procs:
        for stream in (p.stdin, p.stdout, p.stderr):
            if stream:
                try:
                    stream.close()
                except OSError:
                    pass


def _kill(proc):
    if proc.poll() is None:
        proc.kill()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass


class _StderrCollector(threading.Thread):
    """Lê o stderr para não bloquear o processo e guarda o fim (diagnóstico)."""

    def __init__(self, stream, keep=16000):
        super().__init__(daemon=True)
        self.stream = stream
        self.keep = keep
        self.buf = ""

    def run(self):
        for raw in iter(self.stream.readline, b""):
            self.buf = (self.buf + raw.decode("utf-8", "replace"))[-self.keep:]

    def text(self):
        return self.buf


def run_ffmpeg(args, *, expected_duration=None, on_progress=None, check=None, mem_mb=None):
    """Executa `ffmpeg args...` e devolve o stderr (para análise de avisos).

    O progresso é lido de `-progress pipe:1` e reportado como fração [0, 1].
    """
    cmd = ["ffmpeg", "-hide_banner", "-nostdin", "-y", "-progress", "pipe:1", "-nostats", *map(str, args)]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    guard = MemoryGuard(mem_mb)
    err = _StderrCollector(proc.stderr)
    err.start()

    progress = {"value": 0.0}

    def read_progress():
        for raw in iter(proc.stdout.readline, b""):
            line = raw.decode("utf-8", "replace").strip()
            if line.startswith(("out_time_us=", "out_time_ms=")) and expected_duration:
                try:
                    us = int(line.split("=", 1)[1])
                except ValueError:
                    continue
                progress["value"] = max(0.0, min(1.0, us / 1e6 / expected_duration))
                if on_progress:
                    on_progress(progress["value"])

    reader = threading.Thread(target=read_progress, daemon=True)
    reader.start()

    try:
        while proc.poll() is None:
            if check:
                try:
                    check.raise_if_needed()
                except JobError:
                    _kill(proc)
                    raise
            if guard.exceeded(proc):
                _kill(proc)
                raise JobError(OUT_OF_MEMORY, "Falha de processamento por falta de recursos no nó de renderização")
            time.sleep(0.2)
    finally:
        reader.join(timeout=2)
        err.join(timeout=2)
        _close(proc)

    if proc.returncode != 0:
        raise classify_failure(proc.returncode, err.text())
    if on_progress:
        on_progress(1.0)
    return err.text()


def run_pipeline(decoder_args, encoder_args, frame_size, transform, *, total_frames, out_frame_size,
                 on_progress=None, check=None, mem_mb=None):
    """Descodifica para RGB, transforma cada fotograma em Python e volta a codificar.

    Usado no Pan & Crop, para garantir interpolação linear e redimensionamento bilinear
    exatamente como especificado (REQ-VID-CROP-002, REQ-VID-CROP-008).
    `transform(index, frame_bytes) -> bytes` recebe e devolve fotogramas rgb24.
    """
    w, h = frame_size
    frame_len = w * h * 3
    dec = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", *map(str, decoder_args)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    enc = subprocess.Popen(
        ["ffmpeg", "-hide_banner", "-nostdin", "-y", "-loglevel", "error", *map(str, encoder_args)],
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    guard = MemoryGuard(mem_mb)
    dec_err = _StderrCollector(dec.stderr)
    enc_err = _StderrCollector(enc.stderr)
    dec_err.start()
    enc_err.start()

    index = 0
    last_report = 0.0
    try:
        while True:
            if check:
                check.raise_if_needed()
            if index % 30 == 0 and guard.exceeded(dec, enc):
                raise JobError(OUT_OF_MEMORY, "Falha de processamento por falta de recursos no nó de renderização")
            data = dec.stdout.read(frame_len)
            if not data or len(data) < frame_len:
                break
            out = transform(index, data)
            if len(out) != out_frame_size[0] * out_frame_size[1] * 3:
                raise JobError(PROCESSING_ERROR, "Dimensão de fotograma inesperada no Pan & Crop")
            enc.stdin.write(out)
            index += 1
            if on_progress and total_frames:
                frac = min(1.0, index / total_frames)
                if frac - last_report >= 0.01:
                    last_report = frac
                    on_progress(frac)
        enc.stdin.close()
        enc.wait()
        dec.wait()
    except (JobError, BrokenPipeError) as e:
        _kill(dec)
        _kill(enc)
        if isinstance(e, JobError):
            raise
        raise classify_failure(enc.returncode or dec.returncode or 1, enc_err.text() + dec_err.text())
    finally:
        dec_err.join(timeout=2)
        enc_err.join(timeout=2)
        _close(dec, enc)

    if dec.returncode not in (0, None) or enc.returncode not in (0, None):
        raise classify_failure(dec.returncode or enc.returncode, dec_err.text() + enc_err.text())
    if index == 0:
        raise JobError(CORRUPT_INPUT, "Não foi possível descodificar nenhum fotograma do vídeo")
    if on_progress:
        on_progress(1.0)
    return index
