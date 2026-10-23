"""Leitura de metadados com ffprobe (REQ-VID-SUBMIT-001, verificações de saída)."""
import json
import subprocess
from fractions import Fraction


def ffprobe_json(path, *extra):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-print_format", "json", *extra, str(path)],
        capture_output=True,
        check=True,
    )
    return json.loads(out.stdout or b"{}")


def _rate(value):
    try:
        f = Fraction(value)
        return float(f) if f > 0 else None
    except (ValueError, ZeroDivisionError, TypeError):
        return None


def video_info(path):
    """Duração, resolução, FPS, codecs e informação de áudio de um ficheiro."""
    data = ffprobe_json(path, "-show_format", "-show_streams")
    streams = data.get("streams", [])
    v = next((s for s in streams if s.get("codec_type") == "video"), None)
    a = next((s for s in streams if s.get("codec_type") == "audio"), None)
    s = [x for x in streams if x.get("codec_type") == "subtitle"]
    fmt = data.get("format", {})
    info = {
        "format_name": fmt.get("format_name", ""),
        "duration": float(fmt.get("duration") or (v or {}).get("duration") or 0),
        "size": int(fmt.get("size") or 0),
        "has_video": v is not None,
        "has_audio": a is not None,
        "subtitle_streams": len(s),
    }
    if v:
        info.update(
            width=int(v.get("width") or 0),
            height=int(v.get("height") or 0),
            fps=_rate(v.get("avg_frame_rate")) or _rate(v.get("r_frame_rate")) or 0.0,
            video_codec=v.get("codec_name"),
            video_start=float(v.get("start_time") or 0),
            nb_frames=int(v["nb_frames"]) if str(v.get("nb_frames", "")).isdigit() else None,
            video_duration=float(v.get("duration") or 0),
        )
    if a:
        info.update(
            audio_codec=a.get("codec_name"),
            sample_rate=int(a.get("sample_rate") or 0),
            audio_start=float(a.get("start_time") or 0),
            audio_duration=float(a.get("duration") or 0),
        )
    return info


def keyframe_times(path):
    """Instantes dos keyframes (I-frames) do fluxo de vídeo, lidos dos pacotes (sem descodificar)."""
    data = ffprobe_json(
        path, "-select_streams", "v:0", "-show_entries", "packet=pts_time,flags"
    )
    times = []
    for p in data.get("packets", []):
        if "K" in (p.get("flags") or "") and p.get("pts_time") not in (None, "N/A"):
            times.append(float(p["pts_time"]))
    return sorted(set(times))


def stream_md5(path, selector):
    """MD5 dos pacotes de um fluxo (e.g. 'a:0'), sem descodificar: prova cópia sem recodificação."""
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-map", f"0:{selector}", "-c", "copy", "-f", "md5", "-"],
        capture_output=True,
        check=True,
    )
    return out.stdout.decode().strip()
