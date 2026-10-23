const mongoose = require("mongoose");

// Versão de um vídeo (RNG-05): cada operação concluída cria uma nova versão, derivada de outra.
const versionSchema = new mongoose.Schema({
  key: { type: String, required: true }, // nome do objeto no armazenamento (sem prefixo)
  stage: { type: String, enum: ["src", "out"], required: true },
  mime: { type: String, default: "video/mp4" },
  size: { type: Number, default: 0 },
  duration: { type: Number, required: true },
  width: { type: Number, required: true },
  height: { type: Number, required: true },
  fps: { type: Number, required: true },
  has_audio: { type: Boolean, default: false },
  sample_rate: { type: Number, default: null },
  video_codec: { type: String, default: null },
  audio_codec: { type: String, default: null },
  subtitle_streams: { type: Number, default: 0 },
  keyframes: { type: [Number], default: [] },
  parent_id: { type: mongoose.Schema.Types.ObjectId, default: null },
  job_id: { type: mongoose.Schema.Types.ObjectId, default: null },
  procedure: { type: String, default: null },
  params: { type: mongoose.Schema.Types.Mixed, default: null },
  created_at: { type: Date, default: Date.now },
});

const videoSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true }, // dono do projeto
  project_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  name: { type: String, required: true },
  versions: { type: [versionSchema], default: [] },
  active_version: { type: mongoose.Schema.Types.ObjectId, default: null },
  created_at: { type: Date, default: Date.now },
});

module.exports = mongoose.model("video", videoSchema);
