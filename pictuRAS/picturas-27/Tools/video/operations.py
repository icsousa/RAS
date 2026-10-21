"""As cinco operações de vídeo do MVP, construídas sobre FFmpeg.

Cada função recebe os parâmetros já validados pelo serviço projects, volta a verificar o
essencial (defesa em profundidade), executa o processamento e devolve avisos e metadados
do resultado. Os requisitos realizados estão indicados em cada função.
"""
import os

from PIL import Image

import probe
from runner import (
    CORRUPT_INPUT,
    FONT_RENDER,
    INVALID_PARAMS,
    PROCESSING_ERROR,
    JobError,
    run_ffmpeg,
    run_pipeline,
)

X264 = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p"]
MP4 = ["-movflags", "+faststart"]
AV_SYNC_TOLERANCE = 0.050  # REQ-VID-TRIM-007 / DQ-004


# ---------------------------------------------------------------- auxiliares
def even(n):
    n = int(round(n))
    return max(2, n - n % 2)


def target_size(width, height, max_short_side):
    """Dimensão de saída limitada pelo perfil, no lado menor (REQ-VID-SUBMIT-003)."""
    short = min(width, height)
    if not max_short_side or short <= max_short_side:
        return even(width), even(height)
    scale = max_short_side / short
    return even(width * scale), even(height * scale)


def scale_filter(src_w, src_h, max_short_side):
    w, h = target_size(src_w, src_h, max_short_side)
    if (w, h) == (src_w, src_h):
        return None, (w, h)
    return f"scale={w}:{h}:flags=bilinear", (w, h)


def _num(params, key, default=None, lo=None, hi=None):
    value = params.get(key, default)
    try:
        value = float(value)
    except (TypeError, ValueError):
        raise JobError(INVALID_PARAMS, f"Parâmetro '{key}' inválido")
    if (lo is not None and value < lo) or (hi is not None and value > hi):
        raise JobError(INVALID_PARAMS, f"Parâmetro '{key}' fora do intervalo permitido")
    return value


def verify_output(path, *, expect_audio=None):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        raise JobError(PROCESSING_ERROR, "O processamento não produziu nenhum ficheiro")
    info = probe.video_info(path)
    if not info["has_video"] or info["duration"] <= 0:
        raise JobError(CORRUPT_INPUT, "O vídeo resultado não é válido")
    if expect_audio and not info["has_audio"]:
        raise JobError(CORRUPT_INPUT, "Perdeu-se a faixa de áudio durante o processamento")
    return info


# ---------------------------------------------------------------- UC-VID-001: recorte temporal
def trim(inp, out, params, src, ctx):
    """REQ-VID-TRIM-003/004/006/007/008/010."""
    start = _num(params, "start", lo=0)
    end = _num(params, "end", lo=0)
    duration = src["duration"]
    if end > duration + 1e-3:
        end = duration
    if end - start < 0.5:
        raise JobError(INVALID_PARAMS, "O excerto tem de ter pelo menos 0,5 s e o início tem de ser anterior ao fim")

    mode = params.get("mode", "precise")
    vf, (out_w, out_h) = scale_filter(src["width"], src["height"], ctx["max_short_side"])
    warnings = []
    meta = {}

    if mode == "fast" and vf is not None:
        # Corte rápido sem recodificação não consegue reduzir a resolução: usa-se o modo preciso.
        warnings.append("fast_mode_unavailable_resolution")
        mode = "precise"

    if mode == "fast":
        kfs = probe.keyframe_times(inp) or [0.0]
        ks = max([k for k in kfs if k <= start + 1e-6] or [kfs[0]])
        after = [k for k in kfs if k >= end - 1e-6]
        ke = min(after) if after else duration
        meta.update(adjusted_start=round(ks, 3), adjusted_end=round(ke, 3))
        args = [
            "-ss", f"{ks:.6f}", "-i", inp, "-t", f"{ke - ks:.6f}",
            "-map", "0:v:0", "-map", "0:a:0?", "-c", "copy", "-avoid_negative_ts", "make_zero", *MP4, out,
        ]
        expected = ke - ks
    else:
        # -ss antes de -i com recodificação é preciso ao fotograma (REQ-VID-TRIM-010).
        # -xerror aborta perante fotogramas corrompidos (REQ-VID-TRIM-006).
        args = [
            "-xerror", "-ss", f"{start:.6f}", "-i", inp, "-t", f"{end - start:.6f}",
            "-map", "0:v:0", "-map", "0:a:0?",
            *(["-vf", vf] if vf else []),
            "-r", f"{src['fps']:.6f}", *X264, "-c:a", "aac", "-b:a", "160k", *MP4, out,
        ]
        expected = end - start

    run_ffmpeg(args, expected_duration=expected, on_progress=ctx["progress"], check=ctx["check"], mem_mb=ctx["mem_mb"])
    info = verify_output(out, expect_audio=src.get("has_audio"))

    # Verificação de sincronismo e de integridade (REQ-VID-TRIM-006/007)
    if src.get("has_audio") and info.get("has_audio"):
        offset = abs(info.get("video_start", 0) - info.get("audio_start", 0))
        meta["av_offset_ms"] = round(offset * 1000, 1)
        if offset > AV_SYNC_TOLERANCE:
            raise JobError(CORRUPT_INPUT, "Perda de alinhamento entre áudio e vídeo durante a extração")
    if abs(info["duration"] - expected) > max(0.25, 2 / max(src["fps"], 1)):
        raise JobError(CORRUPT_INPUT, "A duração do excerto não corresponde à pedida (ficheiro possivelmente corrompido)")
    meta.update(width=info["width"], height=info["height"], fps=info["fps"])
    if vf is None and (info["width"], info["height"]) != (src["width"], src["height"]):
        raise JobError(PROCESSING_ERROR, "A resolução do excerto difere da origem")
    return {"warnings": warnings, "meta": meta}


# ---------------------------------------------------------------- UC-VID-003: velocidade
def atempo_chain(factor):
    """Decompõe o fator em filtros atempo no intervalo [0.5, 2] (compatível com versões antigas)."""
    parts = []
    f = float(factor)
    while f > 2.0:
        parts.append(2.0)
        f /= 2.0
    while f < 0.5:
        parts.append(0.5)
        f /= 0.5
    parts.append(f)
    return ",".join(f"atempo={p:.6f}" for p in parts)


def speed_segments(duration, factor, segment):
    if not segment:
        return [(0.0, duration, factor)]
    s = max(0.0, float(segment["start"]))
    e = min(duration, float(segment["end"]))
    if e - s < 0.1:
        raise JobError(INVALID_PARAMS, "O segmento de velocidade é demasiado curto")
    segs = []
    if s > 0.01:
        segs.append((0.0, s, 1.0))
    segs.append((s, e, factor))
    if duration - e > 0.01:
        segs.append((e, duration, 1.0))
    return segs


def speed_filtergraph(segments, fps, vf_scale, audio, pitch, sample_rate):
    v_parts, a_parts, v_labels, a_labels = [], [], [], []
    n = len(segments)
    v_parts.append(f"[0:v]split={n}" + "".join(f"[vs{i}]" for i in range(n)) if n > 1 else "[0:v]null[vs0]")
    if audio:
        a_parts.append(f"[0:a]asplit={n}" + "".join(f"[as{i}]" for i in range(n)) if n > 1 else "[0:a]anull[as0]")
    for i, (s, e, f) in enumerate(segments):
        v_parts.append(f"[vs{i}]trim=start={s:.6f}:end={e:.6f},setpts=(PTS-STARTPTS)/{f:.6f}[v{i}]")
        v_labels.append(f"[v{i}]")
        if audio:
            if abs(f - 1.0) < 1e-9:
                tempo = "anull"
            elif pitch:
                tempo = atempo_chain(f)  # mantém o tom (REQ-VID-SPD-005)
            else:
                tempo = f"asetrate={int(sample_rate * f)},aresample={sample_rate}"
            a_parts.append(f"[as{i}]atrim=start={s:.6f}:end={e:.6f},asetpts=PTS-STARTPTS,{tempo}[a{i}]")
            a_labels.append(f"[a{i}]")
    # fps=... duplica/descarta fotogramas, sem interpolação por fluxo ótico (REQ-VID-SPD-007, DQ-009)
    tail = f"fps={fps:.6f}" + (f",{vf_scale}" if vf_scale else "")
    if n > 1:
        v_parts.append("".join(v_labels) + f"concat=n={n}:v=1:a=0,{tail}[vout]")
        if audio:
            a_parts.append("".join(a_labels) + f"concat=n={n}:v=0:a=1[aout]")
    else:
        v_parts.append(f"[v0]{tail}[vout]")
        if audio:
            a_parts.append("[a0]anull[aout]")
    return ";".join(v_parts + a_parts)


def speed(inp, out, params, src, ctx):
    """REQ-VID-SPD-002/003/004/005/007/008."""
    factor = _num(params, "factor", lo=0.1, hi=10.0)
    pitch = bool(params.get("pitch", True))
    remove_audio = bool(params.get("removeAudio", False))
    segments = speed_segments(src["duration"], factor, params.get("segment"))
    expected = sum((e - s) / f for s, e, f in segments)
    vf, _ = scale_filter(src["width"], src["height"], ctx["max_short_side"])
    warnings = []
    if pitch and not (0.5 <= factor <= 2.0) and src.get("has_audio") and not remove_audio:
        warnings.append("pitch_not_guaranteed")  # REQ-VID-SPD-010

    def build(with_audio):
        graph = speed_filtergraph(segments, src["fps"], vf, with_audio, pitch, src.get("sample_rate") or 48000)
        maps = ["-map", "[vout]"] + (["-map", "[aout]", "-c:a", "aac", "-b:a", "160k"] if with_audio else ["-an"])
        return ["-i", inp, "-filter_complex", graph, *maps, *X264, *MP4, out]

    use_audio = bool(src.get("has_audio")) and not remove_audio
    try:
        run_ffmpeg(build(use_audio), expected_duration=expected, on_progress=ctx["progress"],
                   check=ctx["check"], mem_mb=ctx["mem_mb"])
    except JobError as e:
        if not use_audio or e.code != PROCESSING_ERROR:
            raise
        # O áudio não pôde ser processado a esta velocidade: gera-se sem som e avisa-se (REQ-VID-SPD-004)
        run_ffmpeg(build(False), expected_duration=expected, on_progress=ctx["progress"],
                   check=ctx["check"], mem_mb=ctx["mem_mb"])
        warnings.append("audio_removed_incompatible")
        use_audio = False
    info = verify_output(out, expect_audio=use_audio)
    return {"warnings": warnings, "meta": {"duration": info["duration"], "has_audio": info["has_audio"]}}


# ---------------------------------------------------------------- UC-VID-004: legendas e texto
FONTS = {"Noto Sans", "Noto Serif", "DejaVu Sans", "Liberation Sans", "Liberation Serif"}


def ass_time(t):
    cs = int(round(max(0.0, t) * 100))
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def srt_time(t):
    ms = int(round(max(0.0, t) * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def ass_color(hex_color):
    c = (hex_color or "#FFFFFF").lstrip("#")
    if len(c) != 6:
        c = "FFFFFF"
    r, g, b = c[0:2], c[2:4], c[4:6]
    return f"&H00{b}{g}{r}&".upper()


def ass_escape(text):
    return str(text).replace("\\", "⧵").replace("{", "(").replace("}", ")").replace("\r", "").replace("\n", "\\N")


def build_ass(blocks, width, height):
    lines = [
        "[Script Info]", "ScriptType: v4.00+", f"PlayResX: {width}", f"PlayResY: {height}",
        "WrapStyle: 0", "ScaledBorderAndShadow: yes", "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
        "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
        "Alignment, MarginL, MarginR, MarginV, Encoding",
        "Style: Default,Noto Sans,48,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,0,5,10,10,10,1",
        "", "[Events]",
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
    ]
    for b in blocks:
        font = b.get("font") if b.get("font") in FONTS else "Noto Sans"
        size = max(8, int(round(float(b.get("size", 0.06)) * height)))
        x = int(round(float(b.get("x", 0.5)) * width))
        y = int(round(float(b.get("y", 0.85)) * height))
        tags = f"{{\\an5\\pos({x},{y})\\fn{font}\\fs{size}\\c{ass_color(b.get('color'))}" + ("\\b1" if b.get("bold") else "") + "}"
        lines.append(f"Dialogue: 0,{ass_time(b['start'])},{ass_time(b['end'])},Default,,0,0,0,,{tags}{ass_escape(b['text'])}")
    return "\n".join(lines) + "\n"


def build_srt(blocks):
    out = []
    for i, b in enumerate(sorted(blocks, key=lambda x: x["start"]), start=1):
        out += [str(i), f"{srt_time(b['start'])} --> {srt_time(b['end'])}", str(b["text"]).replace("\r", ""), ""]
    return "\n".join(out)


def text(inp, out, params, src, ctx):
    """REQ-VID-TXT-003/004/005/010; áudio copiado (REQ-VID-AUDIO-001)."""
    blocks = params.get("blocks") or []
    if not blocks:
        raise JobError(INVALID_PARAMS, "É necessário pelo menos um bloco de texto")
    for b in blocks:
        s, e = float(b["start"]), float(b["end"])
        if not (0 <= s < e <= src["duration"] + 1e-3):
            raise JobError(INVALID_PARAMS, "Intervalo de um bloco de texto inválido")
    mode = params.get("mode", "hardcode")
    vf, (out_w, out_h) = scale_filter(src["width"], src["height"], ctx["max_short_side"])
    audio = ["-map", "0:a:0?", "-c:a", "copy"]
    warnings = []

    if mode == "softsub":
        srt = os.path.join(ctx["work_dir"], "subs.srt")
        with open(srt, "w", encoding="utf-8") as fh:
            fh.write(build_srt(blocks))
        video = (["-vf", vf, *X264] if vf else ["-c:v", "copy"])
        args = ["-i", inp, "-i", srt, "-map", "0:v:0", *audio[:2], "-map", "1:0", *video, *audio[2:],
                "-c:s", "mov_text", "-metadata:s:s:0", "language=por", *MP4, out]
        run_ffmpeg(args, expected_duration=src["duration"], on_progress=ctx["progress"], check=ctx["check"], mem_mb=ctx["mem_mb"])
        info = verify_output(out, expect_audio=src.get("has_audio"))
        if info["subtitle_streams"] < 1:
            raise JobError(PROCESSING_ERROR, "A faixa de legendas não foi incluída no resultado")
        return {"warnings": warnings, "meta": {"mode": "softsub"}}

    ass = os.path.join(ctx["work_dir"], "subs.ass")
    with open(ass, "w", encoding="utf-8") as fh:
        fh.write(build_ass(blocks, out_w, out_h))
    chain = ",".join(x for x in [vf, f"ass={ass}"] if x)
    args = ["-loglevel", "verbose", "-i", inp, "-map", "0:v:0", *audio[:2], "-vf", chain, *X264, *audio[2:], *MP4, out]
    log = run_ffmpeg(args, expected_duration=src["duration"], on_progress=ctx["progress"], check=ctx["check"], mem_mb=ctx["mem_mb"])
    # A fonte de recurso (fontconfig/libass) cobre os glifos em falta (REQ-VID-TXT-005); se nem ela
    # os tiver, o texto não pode ser desenhado e o trabalho falha (UC-VID-004/E2).
    if "failed to find any fallback with glyph" in log:
        raise JobError(FONT_RENDER, "Há caracteres que nenhuma fonte disponível consegue desenhar")
    if "fontselect: (" in log and "Noto" not in log and "DejaVu" not in log:
        warnings.append("font_fallback_used")
    verify_output(out, expect_audio=src.get("has_audio"))
    return {"warnings": warnings, "meta": {"mode": "hardcode"}}


# ---------------------------------------------------------------- UC-VID-005: filtros de cor
PRESETS = {
    "sepia": "colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131",
    "bw": "hue=s=0",
    "high_contrast": "eq=contrast=1.6:saturation=1.15",
    "cinematic": "eq=contrast=1.1:saturation=0.85,colorbalance=rs=-0.05:bs=0.08:rh=0.08:bh=-0.06",
}


def color_filtergraph(params, vf_scale, lut_path=None):
    preset = params.get("preset") or "none"
    if preset != "none" and preset not in PRESETS:
        raise JobError(INVALID_PARAMS, "Filtro predefinido desconhecido")
    intensity = _num(params, "intensity", 100, 0, 100) / 100.0
    manual = params.get("manual") or {}
    b = _num(manual, "brightness", 0, -1, 1)
    c = _num(manual, "contrast", 1, 0, 2)
    s = _num(manual, "saturation", 1, 0, 3)
    g = _num(manual, "gamma", 1, 0.1, 3)
    head = []
    if (b, c, s, g) != (0, 1, 1, 1):
        head.append(f"eq=brightness={b:.4f}:contrast={c:.4f}:saturation={s:.4f}:gamma={g:.4f}")
    tail = []
    if lut_path:
        tail.append(f"lut3d=file={lut_path}")
    if vf_scale:
        tail.append(vf_scale)
    tail.append("format=yuv420p")
    pre = ",".join(head + ["format=yuv444p"])
    if preset == "none" or intensity <= 0:
        return f"[0:v]{pre},{','.join(tail)}[vout]"
    return (
        f"[0:v]{pre},split[base][fx];"
        f"[fx]{PRESETS[preset]},format=yuv444p[fxo];"
        f"[fxo][base]blend=all_mode=normal:all_opacity={intensity:.4f},{','.join(tail)}[vout]"
    )


def color(inp, out, params, src, ctx):
    """REQ-VID-COL-007/008/010 e LUT 3D (REQ-VID-COL-002/009); áudio copiado (REQ-VID-AUDIO-001)."""
    lut = params.get("lutPath")
    if lut:
        from cube import CubeError, validate_cube_text
        try:
            with open(lut, encoding="utf-8") as fh:
                validate_cube_text(fh.read())
        except (OSError, UnicodeDecodeError, CubeError) as e:
            raise JobError(INVALID_PARAMS, f"Ficheiro LUT inválido ou corrompido: {e}")
    vf, _ = scale_filter(src["width"], src["height"], ctx["max_short_side"])
    graph = color_filtergraph(params, vf, lut)
    args = ["-i", inp, "-filter_complex", graph, "-map", "[vout]", "-map", "0:a:0?", *X264, "-c:a", "copy", *MP4, out]
    run_ffmpeg(args, expected_duration=src["duration"], on_progress=ctx["progress"], check=ctx["check"], mem_mb=ctx["mem_mb"])
    verify_output(out, expect_audio=src.get("has_audio"))
    return {"warnings": [], "meta": {}}


# ---------------------------------------------------------------- UC-VID-002: Pan & Crop
def crop_output_size(src_w, src_h, aspect, max_short_side):
    if aspect >= src_w / src_h:
        w, h = src_w, src_w / aspect
    else:
        w, h = src_h * aspect, src_h
    return target_size(even(w), even(h), max_short_side)


def interpolate(keyframes, t):
    """Interpolação linear da moldura entre keyframes consecutivos (REQ-VID-CROP-002)."""
    if t <= keyframes[0]["t"]:
        k = keyframes[0]
        return k["x"], k["y"], k["w"], k["h"]
    for a, b in zip(keyframes, keyframes[1:]):
        if a["t"] <= t <= b["t"]:
            span = b["t"] - a["t"]
            r = 0.0 if span <= 0 else (t - a["t"]) / span
            return tuple(a[k] + (b[k] - a[k]) * r for k in ("x", "y", "w", "h"))
    k = keyframes[-1]
    return k["x"], k["y"], k["w"], k["h"]


def validate_keyframes(keyframes, src_w, src_h):
    if not keyframes:
        raise JobError(INVALID_PARAMS, "É necessário pelo menos um keyframe")
    kfs = sorted(({k: float(kf[k]) for k in ("t", "x", "y", "w", "h")} for kf in keyframes), key=lambda k: k["t"])
    min_w, min_h = min(320, src_w), min(240, src_h)
    for kf in kfs:
        if kf["w"] < min_w - 0.5 or kf["h"] < min_h - 0.5:
            raise JobError(INVALID_PARAMS, "A área de corte não pode ser inferior a 320x240 píxeis")
        if kf["x"] < -0.5 or kf["y"] < -0.5 or kf["x"] + kf["w"] > src_w + 0.5 or kf["y"] + kf["h"] > src_h + 0.5:
            raise JobError(INVALID_PARAMS, "A moldura de um keyframe sai do fotograma")
    return kfs


def crop(inp, out, params, src, ctx):
    """REQ-VID-CROP-002/004/008/011; áudio copiado (REQ-VID-AUDIO-001)."""
    src_w, src_h, fps = src["width"], src["height"], src["fps"]
    kfs = validate_keyframes(params.get("keyframes"), src_w, src_h)
    aspect = kfs[0]["w"] / kfs[0]["h"]
    out_w, out_h = crop_output_size(src_w, src_h, aspect, ctx["max_short_side"])
    total = src.get("nb_frames") or int(round(src["duration"] * fps))

    def transform(index, data):
        x, y, w, h = interpolate(kfs, index / fps)
        frame = Image.frombytes("RGB", (src_w, src_h), data)
        # Redimensionamento bilinear (REQ-VID-CROP-008, DQ-007), com caixa sub-píxel
        return frame.resize((out_w, out_h), Image.BILINEAR, box=(x, y, x + w, y + h)).tobytes()

    decoder = ["-i", inp, "-map", "0:v:0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-fps_mode", "passthrough", "pipe:1"]
    encoder = [
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{out_w}x{out_h}", "-framerate", f"{fps:.6f}", "-i", "pipe:0",
        "-i", inp, "-map", "0:v:0", "-map", "1:a:0?", *X264, "-c:a", "copy", "-shortest", *MP4, out,
    ]
    frames = run_pipeline(decoder, encoder, (src_w, src_h), transform, total_frames=total,
                          out_frame_size=(out_w, out_h), on_progress=ctx["progress"], check=ctx["check"], mem_mb=ctx["mem_mb"])
    verify_output(out, expect_audio=src.get("has_audio"))
    return {"warnings": [], "meta": {"width": out_w, "height": out_h, "frames": frames, "interpolation": "bilinear"}}


OPERATIONS = {
    "video_trim": trim,
    "video_crop": crop,
    "video_speed": speed,
    "video_text": text,
    "video_color": color,
}
