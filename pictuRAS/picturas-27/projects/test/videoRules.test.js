// Testes das regras de vídeo do serviço projects.  Executar: node --test test/
// Os IDs TST-* correspondem ao Capítulo 10 do relatório.
const test = require("node:test");
const assert = require("node:assert/strict");
const R = require("../utils/videoRules");

const video = { duration: 30, width: 1920, height: 1080, fps: 30, has_audio: true };
const mp4 = { format_name: "mov,mp4,m4a,3gp,3g2,mj2", has_video: true, video_codec: "h264", has_audio: true, audio_codec: "aac", duration: 30, width: 1920, height: 1080, fps: 30 };

function rejects(fn, status, code) {
  assert.throws(fn, (e) => e instanceof R.VideoRuleError && e.status === status && e.code === code);
}

test("TST-SUBMIT-01 aceita MP4/MOV H.264/AAC e rejeita outros formatos", () => {
  assert.equal(R.validateSubmission(mp4, "free"), true);
  rejects(() => R.validateSubmission({ ...mp4, format_name: "avi" }, "free"), 400, "unsupported_format");
  rejects(() => R.validateSubmission({ ...mp4, video_codec: "hevc" }, "free"), 400, "unsupported_codec");
  rejects(() => R.validateSubmission({ ...mp4, audio_codec: "mp3" }, "free"), 400, "unsupported_codec");
  assert.equal(R.validateSubmission({ ...mp4, has_audio: false, audio_codec: undefined }, "free"), true);
});

test("TST-SUBMIT-02 limite de duração por perfil (60/300/3600 s)", () => {
  rejects(() => R.validateSubmission({ ...mp4, duration: 75 }, "anonymous"), 403, "duration_limit");
  assert.equal(R.validateSubmission({ ...mp4, duration: 75 }, "free"), true);
  rejects(() => R.validateSubmission({ ...mp4, duration: 301 }, "free"), 403, "duration_limit");
  assert.equal(R.validateSubmission({ ...mp4, duration: 3600 }, "premium"), true);
});

test("TST-TRIM-07 intervalo inválido é recusado; modo preciso por omissão", () => {
  rejects(() => R.validateJob("video_trim", { start: 5, end: 5.2 }, "free", video), 400, "invalid_interval");
  rejects(() => R.validateJob("video_trim", { start: 6, end: 5 }, "free", video), 400, "invalid_interval");
  rejects(() => R.validateJob("video_trim", { start: 1, end: 31 }, "free", video), 400, "invalid_params");
  const ok = R.validateJob("video_trim", { start: 1, end: 4 }, "anonymous", video);
  assert.deepEqual(ok.op, { start: 1, end: 4, mode: "precise" });
  assert.equal(R.validateJob("video_trim", { start: 1, end: 4, mode: "fast" }, "free", video).op.mode, "fast");
});

test("TST-CROP-05 Pan & Crop: anónimo recusado, Registado até 5 keyframes, moldura mínima", () => {
  const kf = (t, w = 640, h = 360) => ({ t, x: 0, y: 0, w, h });
  rejects(() => R.validateJob("video_crop", { keyframes: [kf(0)] }, "anonymous", video), 403, "tool_not_allowed");
  const six = [0, 1, 2, 3, 4, 5].map((t) => kf(t));
  rejects(() => R.validateJob("video_crop", { keyframes: six }, "free", video), 403, "keyframe_limit");
  assert.equal(R.validateJob("video_crop", { keyframes: six }, "premium", video).op.keyframes.length, 6);
  rejects(() => R.validateJob("video_crop", { keyframes: [kf(0, 300, 168.75)] }, "free", video), 400, "crop_too_small");
  rejects(() => R.validateJob("video_crop", { keyframes: [kf(0), kf(2, 640, 640)] }, "free", video), 400, "invalid_params");
  const ok = R.validateJob("video_crop", { keyframes: [kf(4), kf(0)] }, "free", video);
  assert.deepEqual(ok.op.keyframes.map((k) => k.t), [0, 4]);
});

test("TST-SPD-09 velocidade: limites por perfil e duração máxima após abrandamento", () => {
  rejects(() => R.validateJob("video_speed", { factor: 4 }, "anonymous", video), 403, "speed_limit");
  assert.equal(R.validateJob("video_speed", { factor: 4 }, "free", video).expectedOutputDuration, 7.5);
  const long = { ...video, duration: 200 };
  rejects(() => R.validateJob("video_speed", { factor: 0.5 }, "free", long), 400, "duration_limit");
  const seg = R.validateJob("video_speed", { factor: 2, segment: { start: 5, end: 10 } }, "free", video);
  assert.equal(seg.expectedOutputDuration, 27.5);
  assert.equal(seg.op.pitch, true);
});

test("TST-TXT-05 legendas: anónimo recusado, Soft-sub só Premium, 20 blocos, intervalos", () => {
  const block = (s = 0, e = 2) => ({ text: "Olá", start: s, end: e });
  rejects(() => R.validateJob("video_text", { blocks: [block()] }, "anonymous", video), 403, "tool_not_allowed");
  rejects(() => R.validateJob("video_text", { blocks: [block()], mode: "softsub" }, "free", video), 403, "softsub_premium");
  assert.equal(R.validateJob("video_text", { blocks: [block()], mode: "softsub" }, "premium", video).op.mode, "softsub");
  const many = Array.from({ length: 21 }, () => block());
  rejects(() => R.validateJob("video_text", { blocks: many }, "free", video), 403, "text_block_limit");
  rejects(() => R.validateJob("video_text", { blocks: [block(10, 35)] }, "free", video), 400, "invalid_interval");
  rejects(() => R.validateJob("video_text", { blocks: [block(3, 3)] }, "free", video), 400, "invalid_interval");
  const ok = R.validateJob("video_text", { blocks: [block(0, 5), block(3, 8)] }, "free", video);
  assert.equal(ok.op.blocks.length, 2);
  assert.equal(ok.op.blocks[0].font, "Noto Sans");
});

test("TST-COL-05 cor: LUT só Premium, sem ajuste é recusado", () => {
  const id = "123e4567-e89b-12d3-a456-426614174000";
  rejects(() => R.validateJob("video_color", { lutId: id }, "free", video), 403, "lut_premium");
  assert.equal(R.validateJob("video_color", { lutId: id }, "premium", video).op.lutId, id);
  rejects(() => R.validateJob("video_color", {}, "free", video), 400, "invalid_params");
  rejects(() => R.validateJob("video_color", { preset: "vintage" }, "free", video), 400, "invalid_params");
  const ok = R.validateJob("video_color", { preset: "sepia", intensity: 40 }, "anonymous", video);
  assert.equal(ok.op.intensity, 40);
});

test("TST-COL-06 validação de LUT .cube", () => {
  const n = 17;
  const rows = Array.from({ length: n ** 3 }, () => "0.1 0.2 0.3").join("\n");
  assert.equal(R.validateCube(`TITLE "x"\nLUT_3D_SIZE 17\n${rows}`), 17);
  rejects(() => R.validateCube(`LUT_3D_SIZE 20\n${rows}`), 400, "invalid_lut");
  rejects(() => R.validateCube(`LUT_3D_SIZE 17\n1.2 0 0\n`), 400, "invalid_lut");
  rejects(() => R.validateCube(`LUT_3D_SIZE 17\n0 0 0\n`), 400, "invalid_lut");
});

test("TST-TXT-06 importação de SRT/VTT em UTF-8", () => {
  const srt = "1\n00:00:01,000 --> 00:00:02,500\nOlá\nmundo\n\n2\n00:00:03,000 --> 00:00:04,000\n<i>Adeus</i>\n";
  const blocks = R.parseSubtitles(Buffer.from(srt, "utf8"));
  assert.deepEqual(blocks, [
    { text: "Olá\nmundo", start: 1, end: 2.5 },
    { text: "Adeus", start: 3, end: 4 },
  ]);
  const vtt = "WEBVTT\n\nNOTE comentário\n\n00:01.000 --> 00:02.000 align:start\nOi\n";
  assert.deepEqual(R.parseSubtitles(Buffer.from(vtt, "utf8")), [{ text: "Oi", start: 1, end: 2 }]);
});

test("TST-TXT-07 legendas inválidas: codificação, numeração, tempos", () => {
  const latin1 = Buffer.from("1\n00:00:01,000 --> 00:00:02,000\nAção\n", "latin1");
  rejects(() => R.parseSubtitles(latin1), 400, "invalid_encoding");
  rejects(() => R.parseSubtitles(Buffer.from("x\n00:00:01,000 --> 00:00:02,000\nA\n")), 400, "invalid_subtitles");
  rejects(() => R.parseSubtitles(Buffer.from("1\n00:00:03,000 --> 00:00:02,000\nA\n")), 400, "invalid_subtitles");
  rejects(() => R.parseSubtitles(Buffer.from("1\n00:00:01 --> 00:00:02\nA\n")), 400, "invalid_subtitles");
});

test("perfil público converte Infinity em null", () => {
  const p = R.publicProfile("premium");
  assert.equal(p.maxKeyframes, null);
  assert.equal(R.publicProfile("desconhecido").type, "anonymous");
});
