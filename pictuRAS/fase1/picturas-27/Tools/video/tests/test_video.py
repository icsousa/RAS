"""Testes automáticos do worker de vídeo (FFmpeg real, sem RabbitMQ).

Executar a partir de Tools/video:  python -m unittest discover -s tests -v
Os IDs TST-* correspondem ao Capítulo 10 do relatório.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

TMP = tempfile.mkdtemp(prefix="picturas-video-tests-")
os.environ["VIDEO_DATA_ROOT"] = TMP

import operations  # noqa: E402
import probe  # noqa: E402
import video  # noqa: E402
from cube import CubeError, validate_cube_text  # noqa: E402
from runner import CancelCheck, JobError  # noqa: E402

try:
    import numpy as np
except ImportError:  # pragma: no cover
    np = None


def ff(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *map(str, args)], check=True)


def make_fixtures():
    fx = {}
    fx["src"] = os.path.join(TMP, "src.mp4")  # 1280x720, 30 fps, 6 s, tom de 440 Hz, keyframe a cada 2 s
    ff("-f", "lavfi", "-i", "testsrc2=s=1280x720:r=30:d=6", "-f", "lavfi", "-i", "sine=f=440:r=48000:d=6",
       "-c:v", "libx264", "-preset", "ultrafast", "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
       "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", fx["src"])
    fx["graded"] = os.path.join(TMP, "graded.mp4")  # luminância do fotograma n = (8n mod 256)
    ff("-f", "lavfi", "-i", "color=c=black:s=320x240:r=30:d=4,format=gray,geq=lum='mod(N*8,256)'",
       "-f", "lavfi", "-i", "sine=f=440:r=48000:d=4", "-c:v", "libx264", "-preset", "ultrafast", "-qp", "0",
       "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", fx["graded"])
    fx["gray"] = os.path.join(TMP, "gray.mp4")  # cinzento médio, para medir a cor
    ff("-f", "lavfi", "-i", "color=c=0x808080:s=640x360:r=25:d=2", "-f", "lavfi", "-i", "sine=f=440:r=48000:d=2",
       "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", fx["gray"])
    return fx


FX = make_fixtures()


def ctx(work, **kw):
    c = {"progress": lambda f: None, "check": CancelCheck(None, None), "mem_mb": None,
         "max_short_side": None, "work_dir": work}
    c.update(kw)
    return c


def frame_rgb(path, t, size=None):
    vf = ["-vf", f"scale={size[0]}:{size[1]}"] if size else []
    out = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(t), "-i", path, "-frames:v", "1", *vf,
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return out


def mean_rgb(data):
    n = len(data) // 3
    return tuple(sum(data[i::3]) / n for i in range(3))


class Base(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.mkdtemp(dir=TMP)
        self.out = os.path.join(self.work, "out.mp4")

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def info(self, key):
        return probe.video_info(FX[key])


class TestTrim(Base):
    def test_TST_TRIM_01_precise_cut_is_frame_accurate(self):
        """REQ-VID-TRIM-010: t_in = 2,000 s a 30 fps → 1.º fotograma é o 60 da origem."""
        operations.trim(FX["graded"], self.out, {"start": 2.0, "end": 3.0}, self.info("graded"), ctx(self.work))
        luma = mean_rgb(frame_rgb(self.out, 0))[0]
        self.assertAlmostEqual(luma, (60 * 8) % 256, delta=4)

    def test_TST_TRIM_02_preserves_properties_and_sync(self):
        """REQ-VID-TRIM-007/008: mesma resolução e FPS; desfasamento A/V ≤ 50 ms."""
        r = operations.trim(FX["src"], self.out, {"start": 1.0, "end": 4.0}, self.info("src"), ctx(self.work))
        info = probe.video_info(self.out)
        self.assertEqual((info["width"], info["height"]), (1280, 720))
        self.assertAlmostEqual(info["fps"], 30, delta=0.01)
        self.assertAlmostEqual(info["duration"], 3.0, delta=0.1)
        print(f"\n[TST-TRIM-02] desfasamento A/V medido: {r['meta']['av_offset_ms']} ms")
        self.assertLessEqual(r["meta"]["av_offset_ms"], 50)

    def test_TST_TRIM_03_fast_mode_aligns_to_keyframes_without_reencoding(self):
        """REQ-VID-TRIM-003: alinhamento a keyframes e cópia do fluxo de vídeo."""
        r = operations.trim(FX["src"], self.out, {"start": 2.5, "end": 3.2, "mode": "fast"}, self.info("src"), ctx(self.work))
        self.assertEqual(r["meta"]["adjusted_start"], 2.0)
        self.assertEqual(r["meta"]["adjusted_end"], 4.0)
        src_first = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-read_intervals", "2%+#1",
                                    "-show_entries", "packet=size", "-of", "csv=p=0", FX["src"]], capture_output=True, text=True).stdout.split()[0]
        out_first = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-read_intervals", "%+#1",
                                    "-show_entries", "packet=size", "-of", "csv=p=0", self.out], capture_output=True, text=True).stdout.split()[0]
        self.assertEqual(src_first, out_first)  # o mesmo pacote: não houve recodificação

    def test_TST_TRIM_04_rejects_short_or_inverted_interval(self):
        """REQ-VID-TRIM-004 (defesa no worker)."""
        for p in ({"start": 5, "end": 5.2}, {"start": 3, "end": 2}):
            with self.assertRaises(JobError) as cm:
                operations.trim(FX["src"], self.out, p, self.info("src"), ctx(self.work))
            self.assertEqual(cm.exception.code, "invalid_params")

    def test_TST_TRIM_05_corrupted_input_aborts(self):
        """REQ-VID-TRIM-006 / REQ-VID-STATUS-002: ficheiro corrompido → falha com causa."""
        bad = os.path.join(self.work, "bad.mp4")
        with open(FX["src"], "rb") as fh:
            data = bytearray(fh.read())
        mid = len(data) // 3
        data[mid:mid + 60000] = os.urandom(60000)
        with open(bad, "wb") as fh:
            fh.write(bytes(data))
        with self.assertRaises(JobError) as cm:
            operations.trim(bad, self.out, {"start": 0.5, "end": 5.5}, self.info("src"), ctx(self.work))
        self.assertIn(cm.exception.code, ("corrupt_input", "processing_error"))

    @unittest.skipUnless(os.getenv("RUN_PERF") == "1", "teste de desempenho: RUN_PERF=1")
    def test_TST_TRIM_06_fast_cut_100MB_under_10s(self):
        """REQ-VID-TRIM-009: corte rápido de um vídeo de ~100 MB em menos de 10 s."""
        big = os.path.join(TMP, "big.mp4")
        if not os.path.exists(big):
            ff("-f", "lavfi", "-i", "testsrc2=s=1920x1080:r=30:d=40", "-f", "lavfi", "-i", "sine=f=440:d=40",
               "-c:v", "libx264", "-preset", "ultrafast", "-b:v", "20M", "-g", "60", "-c:a", "aac", "-shortest", big)
        size_mb = os.path.getsize(big) / 1e6
        t0 = time.monotonic()
        operations.trim(big, self.out, {"start": 5, "end": 35, "mode": "fast"}, probe.video_info(big), ctx(self.work))
        elapsed = time.monotonic() - t0
        print(f"\n[TST-TRIM-06] ficheiro {size_mb:.0f} MB, corte rápido em {elapsed:.2f} s")
        self.assertGreater(size_mb, 90)
        self.assertLess(elapsed, 10)


class TestSpeed(Base):
    def test_TST_SPD_01_duration_scales_with_factor(self):
        """REQ-VID-SPD-001: D_nova = D / fator."""
        operations.speed(FX["src"], self.out, {"factor": 2.0}, self.info("src"), ctx(self.work))
        self.assertAlmostEqual(probe.video_info(self.out)["duration"], 3.0, delta=0.1)

    def test_TST_SPD_02_slow_motion_duplicates_frames(self):
        """REQ-VID-SPD-007: a 0.5x os fotogramas em falta são duplicados (sem fluxo ótico)."""
        operations.speed(FX["graded"], self.out, {"factor": 0.5}, self.info("graded"), ctx(self.work))
        info = probe.video_info(self.out)
        self.assertAlmostEqual(info["duration"], 8.0, delta=0.15)
        self.assertAlmostEqual(info["fps"], 30, delta=0.01)
        lumas = []
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", self.out, "-frames:v", "40", "-f", "rawvideo",
                              "-pix_fmt", "gray", "-"], capture_output=True, check=True).stdout
        size = 320 * 240
        for i in range(0, len(raw) // size):
            frame = raw[i * size:(i + 1) * size]
            lumas.append(sum(frame[::97]) / len(frame[::97]))
        pairs = sum(1 for a, b in zip(lumas[0::2], lumas[1::2]) if abs(a - b) < 2)
        self.assertGreaterEqual(pairs, len(lumas) // 2 - 1)

    @unittest.skipIf(np is None, "numpy indisponível")
    def test_TST_SPD_03_pitch_is_preserved(self):
        """REQ-VID-SPD-005: tom de 440 Hz a 1.5x mantém-se entre 431 e 449 Hz."""
        operations.speed(FX["src"], self.out, {"factor": 1.5, "pitch": True}, self.info("src"), ctx(self.work))
        pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", self.out, "-ac", "1", "-ar", "48000", "-f", "s16le", "-"],
                             capture_output=True, check=True).stdout
        sig = np.frombuffer(pcm, dtype=np.int16).astype(float)
        spec = np.abs(np.fft.rfft(sig * np.hanning(len(sig))))
        freq = np.fft.rfftfreq(len(sig), 1 / 48000)[int(np.argmax(spec))]
        print(f"\n[TST-SPD-03] frequência dominante a 1.5x: {freq:.1f} Hz")
        self.assertTrue(431 <= freq <= 449, f"frequência medida {freq:.1f} Hz")

    def test_TST_SPD_04_speed_ramp_only_changes_segment(self):
        """REQ-VID-SPD-003: só o troço 2–4 s é acelerado a 2x → duração 5 s."""
        operations.speed(FX["src"], self.out, {"factor": 2.0, "segment": {"start": 2, "end": 4}}, self.info("src"), ctx(self.work))
        self.assertAlmostEqual(probe.video_info(self.out)["duration"], 5.0, delta=0.15)

    def test_TST_SPD_05_timeout_aborts_job(self):
        """REQ-VID-SPD-006: excedido o tempo máximo, o trabalho é abortado."""
        with self.assertRaises(JobError) as cm:
            operations.speed(FX["src"], self.out, {"factor": 0.25}, self.info("src"),
                             ctx(self.work, check=CancelCheck(None, 0.3)))
        self.assertEqual(cm.exception.code, "timeout")

    def test_TST_SPD_06_remove_audio_option(self):
        """REQ-VID-SPD-008: opção de remover a faixa de áudio."""
        operations.speed(FX["src"], self.out, {"factor": 2.0, "removeAudio": True}, self.info("src"), ctx(self.work))
        self.assertFalse(probe.video_info(self.out)["has_audio"])

    def test_TST_SPD_07_audio_failure_falls_back_to_silent_video(self):
        """REQ-VID-SPD-004: falha no processamento do áudio → vídeo sem som com aviso."""
        real = operations.run_ffmpeg
        calls = {"n": 0}

        def flaky(args, **kw):
            calls["n"] += 1
            if "[aout]" in args:
                raise JobError("processing_error", "simulado: áudio incompatível")
            return real(args, **kw)

        operations.run_ffmpeg = flaky
        try:
            r = operations.speed(FX["src"], self.out, {"factor": 2.0}, self.info("src"), ctx(self.work))
        finally:
            operations.run_ffmpeg = real
        self.assertIn("audio_removed_incompatible", r["warnings"])
        self.assertFalse(probe.video_info(self.out)["has_audio"])

    def test_TST_SPD_08_atempo_chain_stays_in_range(self):
        for f in (0.1, 0.25, 0.5, 1.7, 4, 10):
            parts = [float(x.split("=")[1]) for x in operations.atempo_chain(f).split(",")]
            self.assertTrue(all(0.5 <= p <= 2.0 for p in parts))
            prod = 1.0
            for p in parts:
                prod *= p
            self.assertAlmostEqual(prod, f, places=4)


class TestCrop(Base):
    def test_TST_CROP_01_linear_interpolation(self):
        """REQ-VID-CROP-002: a 2 s entre [0,0,640,360] (0 s) e [640,360,640,360] (4 s) → [320,180,640,360]."""
        kfs = [{"t": 0, "x": 0, "y": 0, "w": 640, "h": 360}, {"t": 4, "x": 640, "y": 360, "w": 640, "h": 360}]
        self.assertEqual(operations.interpolate(kfs, 2), (320, 180, 640, 360))
        self.assertEqual(operations.interpolate(kfs, -1), (0, 0, 640, 360))
        self.assertEqual(operations.interpolate(kfs, 9), (640, 360, 640, 360))

    def test_TST_CROP_02_output_and_audio_copy(self):
        """REQ-VID-CROP-011 e REQ-VID-AUDIO-001: resolução de saída e áudio idêntico (MD5)."""
        kfs = [{"t": 0, "x": 0, "y": 0, "w": 640, "h": 360}, {"t": 5, "x": 600, "y": 300, "w": 640, "h": 360}]
        r = operations.crop(FX["src"], self.out, {"keyframes": kfs}, self.info("src"), ctx(self.work))
        info = probe.video_info(self.out)
        self.assertEqual((info["width"], info["height"]), (1280, 720))
        self.assertEqual(r["meta"]["interpolation"], "bilinear")
        self.assertEqual(probe.stream_md5(FX["src"], "a:0"), probe.stream_md5(self.out, "a:0"))

    def test_TST_CROP_03_vertical_reframe(self):
        """Rácio 9:16 a partir de 16:9 → saída 9:16 com a altura da origem."""
        kfs = [{"t": 0, "x": 100, "y": 0, "w": 405, "h": 720}]
        operations.crop(FX["src"], self.out, {"keyframes": kfs}, self.info("src"), ctx(self.work))
        info = probe.video_info(self.out)
        self.assertEqual((info["width"], info["height"]), (404, 720))

    def test_TST_CROP_04_rejects_too_small_box(self):
        """REQ-VID-CROP-004 (defesa no worker)."""
        with self.assertRaises(JobError):
            operations.crop(FX["src"], self.out, {"keyframes": [{"t": 0, "x": 0, "y": 0, "w": 200, "h": 150}]},
                            self.info("src"), ctx(self.work))


class TestText(Base):
    blocks = [{"text": "Olá PictuRAS", "start": 0.5, "end": 1.5, "x": 0.5, "y": 0.5, "size": 0.15, "color": "#FF0000"}]

    def test_TST_TXT_01_hardcode_draws_text_and_copies_audio(self):
        """REQ-VID-TXT-003 e REQ-VID-AUDIO-001."""
        operations.text(FX["gray"], self.out, {"blocks": self.blocks, "mode": "hardcode"}, self.info("gray"), ctx(self.work))
        inside = mean_rgb(frame_rgb(self.out, 1.0))
        outside = mean_rgb(frame_rgb(self.out, 1.8))
        self.assertGreater(inside[0] - inside[1], outside[0] - outside[1] + 1)  # há vermelho só durante o bloco
        self.assertEqual(probe.stream_md5(FX["gray"], "a:0"), probe.stream_md5(self.out, "a:0"))

    def test_TST_TXT_02_softsub_adds_subtitle_track(self):
        """REQ-VID-TXT-004: faixa mov_text separada; vídeo copiado."""
        operations.text(FX["gray"], self.out, {"blocks": self.blocks, "mode": "softsub"}, self.info("gray"), ctx(self.work))
        data = probe.ffprobe_json(self.out, "-show_streams")
        codecs = [s["codec_name"] for s in data["streams"]]
        self.assertIn("mov_text", codecs)

    def test_TST_TXT_03_fallback_font_for_missing_glyphs(self):
        """REQ-VID-TXT-005: caracteres CJK numa fonte sem CJK são desenhados com a fonte de recurso."""
        blocks = [dict(self.blocks[0], text="Ação — 漢字", font="Liberation Sans")]
        r = operations.text(FX["gray"], self.out, {"blocks": blocks, "mode": "hardcode"}, self.info("gray"), ctx(self.work))
        self.assertNotIn("font_render", r["warnings"])
        self.assertTrue(os.path.exists(self.out))

    @unittest.skipUnless(os.getenv("RUN_PERF") == "1", "teste de desempenho: RUN_PERF=1")
    def test_TST_TXT_08_hardcode_time_under_2_5x_duration(self):
        """REQ-VID-TXT-006: vídeo 1080p de 60 s com 10 blocos em ≤ 150 s."""
        src = os.path.join(TMP, "hd60.mp4")
        if not os.path.exists(src):
            ff("-f", "lavfi", "-i", "testsrc2=s=1920x1080:r=30:d=60", "-f", "lavfi", "-i", "sine=f=440:d=60",
               "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", "-shortest", src)
        blocks = [{"text": f"Legenda número {i + 1}", "start": i * 6, "end": i * 6 + 5, "x": 0.5, "y": 0.85, "size": 0.06}
                  for i in range(10)]
        t0 = time.monotonic()
        operations.text(src, self.out, {"blocks": blocks, "mode": "hardcode"}, probe.video_info(src), ctx(self.work))
        elapsed = time.monotonic() - t0
        print(f"\n[TST-TXT-08] hardcode de 60 s 1080p com 10 blocos em {elapsed:.1f} s")
        self.assertLessEqual(elapsed, 150)

    def test_TST_TXT_04_ass_escaping_and_times(self):
        ass = operations.build_ass([{"text": "a{b}\nc", "start": 61.234, "end": 62, "x": 0.5, "y": 0.5}], 1280, 720)
        self.assertIn("0:01:01.23", ass)
        self.assertIn("a(b)\\Nc", ass)
        srt = operations.build_srt([{"text": "x", "start": 3661.5, "end": 3662}])
        self.assertIn("01:01:01,500 --> 01:01:02,000", srt)


class TestColor(Base):
    def test_TST_COL_01_sepia_intensity(self):
        """REQ-VID-COL-007/010: sépia a 100% torna o cinzento quente; a 0% não altera."""
        operations.color(FX["gray"], self.out, {"preset": "sepia", "intensity": 100}, self.info("gray"), ctx(self.work))
        r, g, b = mean_rgb(frame_rgb(self.out, 1.9))
        self.assertGreater(r, g)
        self.assertGreater(g, b + 10)
        out0 = os.path.join(self.work, "zero.mp4")
        operations.color(FX["gray"], out0, {"preset": "sepia", "intensity": 0}, self.info("gray"), ctx(self.work))
        r0, g0, b0 = mean_rgb(frame_rgb(out0, 0.5))
        self.assertLess(abs(r0 - b0), 6)

    def test_TST_COL_02_manual_adjustments_and_audio_copy(self):
        """REQ-VID-COL-008 e REQ-VID-AUDIO-001."""
        operations.color(FX["gray"], self.out, {"manual": {"brightness": 0.2}}, self.info("gray"), ctx(self.work))
        self.assertGreater(mean_rgb(frame_rgb(self.out, 0.5))[0], mean_rgb(frame_rgb(FX["gray"], 0.5))[0] + 20)
        self.assertEqual(probe.stream_md5(FX["gray"], "a:0"), probe.stream_md5(self.out, "a:0"))

    def test_TST_COL_03_lut_identity(self):
        """REQ-VID-COL-002 (aplicação de LUT 3D): LUT identidade 17³ não altera a cor."""
        n = 17
        lines = ["LUT_3D_SIZE 17"] + [f"{r/(n-1):.6f} {g/(n-1):.6f} {b/(n-1):.6f}"
                                      for b in range(n) for g in range(n) for r in range(n)]
        lut = os.path.join(self.work, "id.cube")
        open(lut, "w").write("\n".join(lines))
        operations.color(FX["gray"], self.out, {"lutPath": lut}, self.info("gray"), ctx(self.work))
        self.assertLess(abs(mean_rgb(frame_rgb(self.out, 0.5))[0] - mean_rgb(frame_rgb(FX["gray"], 0.5))[0]), 4)

    def test_TST_COL_04_cube_validation(self):
        """REQ-VID-COL-009: grelhas e valores inválidos são rejeitados."""
        ok = "LUT_3D_SIZE 17\n" + "\n".join("0.5 0.5 0.5" for _ in range(17 ** 3))
        self.assertEqual(validate_cube_text(ok), 17)
        bad_cases = [
            "LUT_3D_SIZE 20\n" + "\n".join("0 0 0" for _ in range(8000)),
            "LUT_3D_SIZE 17\n" + "\n".join("1.5 0 0" for _ in range(17 ** 3)),
            "LUT_3D_SIZE 17\n0 0 0\n",
            "0 0 0\n",
            "LUT_1D_SIZE 1024\n",
        ]
        for text in bad_cases:
            with self.assertRaises(CubeError):
                validate_cube_text(text)


class TestTransversal(Base):
    def test_TST_SUBMIT_03_output_resolution_capped(self):
        """REQ-VID-SUBMIT-003: 1280x720 com limite 480p → 852x480, rácio mantido."""
        operations.color(FX["src"], self.out, {"preset": "bw"}, self.info("src"), ctx(self.work, max_short_side=480))
        info = probe.video_info(self.out)
        self.assertEqual((info["width"], info["height"]), (852, 480))
        self.assertEqual(operations.target_size(1080, 1920, 720), (720, 1280))

    def test_TST_STATUS_01_cancel_while_processing(self):
        """REQ-VID-STATUS-003: o ficheiro CANCEL interrompe o FFmpeg."""
        cancel = os.path.join(self.work, "CANCEL")
        threading.Timer(0.4, lambda: open(cancel, "w").close()).start()
        with self.assertRaises(JobError) as cm:
            operations.speed(FX["src"], self.out, {"factor": 0.25}, self.info("src"), ctx(self.work, check=CancelCheck(cancel, None)))
        self.assertEqual(cm.exception.code, "cancelled")

    def test_TST_STATUS_02_memory_limit_fails_fast(self):
        """REQ-VID-STATUS-005: limite de memória excedido → falha out_of_memory."""
        with self.assertRaises(JobError) as cm:
            operations.color(FX["src"], self.out, {"preset": "sepia"}, self.info("src"), ctx(self.work, mem_mb=60))
        self.assertEqual(cm.exception.code, "out_of_memory")
        with self.assertRaises(JobError) as cm:
            kfs = [{"t": 0, "x": 0, "y": 0, "w": 640, "h": 360}]
            operations.crop(FX["src"], self.out, {"keyframes": kfs}, self.info("src"), ctx(self.work, mem_mb=60))
        self.assertEqual(cm.exception.code, "out_of_memory")

    def test_TST_STATUS_03_process_job_messages(self):
        """REQ-VID-STATUS-001/002: mensagens de progresso, sucesso e erro com causa."""
        msgs = []
        req = {"jobId": "j1", "messageId": "video-job-j1", "procedure": "video_color",
               "parameters": {"inputVideoURI": FX["gray"], "outputVideoURI": self.out, "workDir": self.work,
                              "op": {"preset": "bw"}}}
        video.process_job(req, msgs.append)
        kinds = [m["type"] for m in msgs]
        self.assertEqual(kinds[0], "progress")
        self.assertEqual(kinds[-1], "success")
        self.assertEqual(msgs[-1]["output"]["videoURI"], self.out)

        msgs.clear()
        bad = dict(req, parameters=dict(req["parameters"], op={"preset": "nope"}))
        video.process_job(bad, msgs.append)
        self.assertEqual(msgs[-1]["type"], "error")
        self.assertEqual(msgs[-1]["error"]["code"], "invalid_params")
        self.assertFalse(os.path.exists(self.out))

    def test_TST_STATUS_04_cancelled_before_start(self):
        msgs = []
        open(os.path.join(self.work, "CANCEL"), "w").close()
        req = {"jobId": "j2", "procedure": "video_color",
               "parameters": {"inputVideoURI": FX["gray"], "outputVideoURI": self.out, "workDir": self.work, "op": {}}}
        video.process_job(req, msgs.append)
        self.assertEqual(msgs[-1]["error"]["code"], "cancelled")

    def test_TST_STATUS_05_rejects_paths_outside_data_root(self):
        msgs = []
        req = {"jobId": "j3", "procedure": "video_color",
               "parameters": {"inputVideoURI": "/etc/passwd", "outputVideoURI": self.out, "workDir": self.work}}
        video.process_job(req, msgs.append)
        self.assertEqual(msgs[-1]["error"]["code"], "invalid_params")


if __name__ == "__main__":
    unittest.main()
