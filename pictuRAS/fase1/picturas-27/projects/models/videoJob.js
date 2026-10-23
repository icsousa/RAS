const mongoose = require("mongoose");

// Trabalho de processamento (modelo de domínio, Secção 3.3; REQ-VID-STATUS-001).
const STATUSES = ["queued", "processing", "completed", "failed", "cancelled"];

const videoJobSchema = new mongoose.Schema(
  {
    video_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    project_id: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    owner_id: { type: mongoose.Schema.Types.ObjectId, required: true },
    runner_id: { type: String, required: true }, // quem pediu (pode ser um convidado por link)
    runner_type: { type: String, required: true },
    source_version: { type: mongoose.Schema.Types.ObjectId, required: true },
    procedure: { type: String, required: true },
    params: { type: mongoose.Schema.Types.Mixed, default: {} },
    status: { type: String, enum: STATUSES, default: "queued", index: true },
    progress: { type: Number, default: 0 },
    quota_reserved: { type: Boolean, default: false }, // RNG-01: reservada ao criar, devolvida se falhar
    error_code: { type: String, default: null },
    error_message: { type: String, default: null },
    warnings: { type: [String], default: [] },
    meta: { type: mongoose.Schema.Types.Mixed, default: {} },
    result_version: { type: mongoose.Schema.Types.ObjectId, default: null },
    work_dir: { type: String, default: null },
    started_at: { type: Date, default: null },
    finished_at: { type: Date, default: null },
  },
  { timestamps: true },
);

videoJobSchema.statics.ACTIVE = ["queued", "processing"];
videoJobSchema.statics.FINAL = ["completed", "failed", "cancelled"];

module.exports = mongoose.model("video_job", videoJobSchema);
