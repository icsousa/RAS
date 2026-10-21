// Leitura de metadados com ffprobe (instalado no contentor do serviço projects).
// REQ-VID-SUBMIT-001: formato, codecs, duração, resolução, FPS, áudio e mapa de keyframes.
const { execFile } = require("child_process");

function run(args) {
  return new Promise((resolve, reject) => {
    execFile("ffprobe", args, { maxBuffer: 64 * 1024 * 1024 }, (err, stdout) => {
      if (err) return reject(err);
      try {
        resolve(JSON.parse(stdout || "{}"));
      } catch (e) {
        reject(e);
      }
    });
  });
}

function rate(value) {
  if (!value || value === "0/0") return 0;
  const [a, b] = String(value).split("/").map(Number);
  return b ? a / b : a || 0;
}

async function probeVideo(path) {
  const data = await run(["-v", "error", "-print_format", "json", "-show_format", "-show_streams", path]);
  const streams = data.streams || [];
  const v = streams.find((s) => s.codec_type === "video");
  const a = streams.find((s) => s.codec_type === "audio");
  const fmt = data.format || {};
  return {
    format_name: fmt.format_name || "",
    duration: Number(fmt.duration || v?.duration || 0),
    size: Number(fmt.size || 0),
    has_video: !!v,
    has_audio: !!a,
    width: Number(v?.width || 0),
    height: Number(v?.height || 0),
    fps: rate(v?.avg_frame_rate) || rate(v?.r_frame_rate),
    video_codec: v?.codec_name || null,
    audio_codec: a?.codec_name || null,
    sample_rate: a ? Number(a.sample_rate || 0) : null,
    subtitle_streams: streams.filter((s) => s.codec_type === "subtitle").length,
  };
}

// Instantes dos keyframes, lidos dos pacotes (sem descodificar o vídeo).
async function keyframeTimes(path) {
  const data = await run(["-v", "error", "-select_streams", "v:0", "-show_entries", "packet=pts_time,flags", "-print_format", "json", path]);
  const times = (data.packets || [])
    .filter((p) => (p.flags || "").includes("K") && p.pts_time !== undefined && p.pts_time !== "N/A")
    .map((p) => Math.round(Number(p.pts_time) * 1000) / 1000);
  return [...new Set(times)].sort((x, y) => x - y);
}

module.exports = { probeVideo, keyframeTimes };
