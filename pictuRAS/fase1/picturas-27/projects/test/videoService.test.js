// Testes do ciclo de vida dos trabalhos de vídeo com dependências simuladas
// (sem MongoDB, S3, RabbitMQ nem users-ms).  Executar: node --test test/*.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");
const { createVideoService } = require("../services/videoService");

function setup({ type = "free", quota = 5 } = {}) {
  const dataRoot = fs.mkdtempSync(path.join(os.tmpdir(), "vid-"));
  const videos = new Map();
  const jobs = new Map();
  const published = [];
  const ws = [];
  const deferred = [];
  const state = { type, quota, reserved: 0, refunded: 0, stored: new Map() };
  const id = () => crypto.randomBytes(12).toString("hex");
  const clone = (o) => structuredClone(o);

  const repo = {
    newId: id,
    createVideo: async (doc) => {
      const v = { _id: id(), created_at: new Date(), ...clone(doc) };
      videos.set(v._id, v);
      return clone(v);
    },
    getVideo: async (owner, project, vid) => {
      const v = videos.get(String(vid));
      return v && v.user_id === owner && v.project_id === project ? clone(v) : null;
    },
    getVideoById: async (vid) => clone(videos.get(String(vid))),
    listVideos: async (owner, project) => [...videos.values()].filter((v) => v.user_id === owner && v.project_id === project).map(clone),
    saveVideo: async (v) => videos.set(String(v._id), clone(v)),
    deleteVideo: async (vid) => videos.delete(String(vid)),
    createJob: async (doc) => {
      const j = { _id: id(), createdAt: new Date(), warnings: [], meta: {}, ...clone(doc) };
      jobs.set(j._id, j);
      return clone(j);
    },
    getJob: async (jid) => (jobs.has(String(jid)) ? clone(jobs.get(String(jid))) : null),
    saveJob: async (j) => jobs.set(String(j._id), clone(j)),
    findActiveJob: async (vid) => [...jobs.values()].find((j) => String(j.video_id) === String(vid) && ["queued", "processing"].includes(j.status)) || null,
    listJobs: async (vid) => [...jobs.values()].filter((j) => String(j.video_id) === String(vid)),
  };
  const storage = {
    upload: async (o, p, stage, file) => {
      const key = `${id()}.mp4`;
      state.stored.set(key, fs.readFileSync(file));
      return key;
    },
    download: async (o, p, stage, key, dest) => fs.writeFileSync(dest, state.stored.get(key) || "video"),
    publicUrl: async (o, p, stage, key) => `https://localhost:8080/s3/${key}`,
    remove: async (o, p, stage, key) => state.stored.delete(key),
  };
  const users = {
    type: async () => state.type,
    reserve: async () => {
      if (state.quota <= 0) return false;
      state.quota--;
      state.reserved++;
      return true;
    },
    refund: async () => {
      state.quota++;
      state.refunded++;
    },
  };
  const info = { format_name: "mov,mp4", has_video: true, video_codec: "h264", has_audio: true, audio_codec: "aac", duration: 20, width: 1280, height: 720, fps: 30, size: 1000 };
  const probe = { probeVideo: async () => ({ ...info, ...(state.info || {}) }), keyframeTimes: async () => [0, 2, 4] };
  const queue = { publishRequest: async (m) => published.push(m), publishWs: async (m) => ws.push(m) };
  const svc = createVideoService({ repo, storage, users, queue, probe, dataRoot, defer: (fn) => deferred.push(fn), log: { error() {} } });
  const runDeferred = async () => {
    while (deferred.length) await deferred.shift()();
  };
  return { svc, state, published, ws, jobs, videos, runDeferred, dataRoot };
}

const file = { buffer: Buffer.from("fake mp4"), originalname: "praia.mp4", mimetype: "video/mp4" };
const ctxBase = { owner: "u1", project: "p1", callerId: "u1" };

async function uploaded(env) {
  return env.svc.uploadVideo({ ...ctxBase, file });
}

test("TST-SUBMIT-04 upload cria vídeo com versão original e mapa de keyframes", async () => {
  const env = setup();
  const v = await uploaded(env);
  assert.equal(v.versions.length, 1);
  assert.equal(v.active.keyframe_count, 3);
  assert.match(v.active.url, /^https:/);
});

test("TST-SUBMIT-05 upload acima da duração do perfil é rejeitado sem guardar nada", async () => {
  const env = setup({ type: "anonymous" });
  env.state.info = { duration: 75 };
  await assert.rejects(uploaded(env), (e) => e.code === "duration_limit" && e.status === 403);
  assert.equal(env.videos.size, 0);
  assert.equal(env.state.stored.size, 0);
});

test("TST-QUOTA-01 sucesso: a operação reservada fica debitada; nova versão ativa derivada da origem", async () => {
  const env = setup();
  const v = await uploaded(env);
  const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 1, end: 5 } });
  assert.equal(job.status, "queued");
  assert.equal(env.state.quota, 4);
  await env.runDeferred();
  assert.equal(env.published.length, 1);
  const req = env.published[0];
  assert.equal(req.parameters.maxShortSide, 1080);
  fs.writeFileSync(req.parameters.outputVideoURI, "resultado");
  await env.svc.handleResult({ jobId: job._id, type: "progress", progress: 40 });
  assert.equal(env.jobs.get(job._id).status, "processing");
  await env.svc.handleResult({ jobId: job._id, type: "success", output: { videoURI: req.parameters.outputVideoURI, info: { duration: 4, width: 1280, height: 720, fps: 30, has_audio: true } } });
  const after = await env.svc.getVideo("u1", "p1", v._id);
  assert.equal(after.versions.length, 2);
  assert.equal(after.active.parent_id, v.active._id);
  assert.equal(env.jobs.get(job._id).status, "completed");
  assert.equal(env.state.quota, 4);
  assert.equal(env.state.refunded, 0);
  assert.equal(fs.existsSync(req.parameters.workDir), false); // temporários eliminados
  assert.ok(env.ws.some((m) => m.type === "video-job" && m.job.status === "completed"));
});

test("TST-QUOTA-02 falha: a operação é devolvida, a origem mantém-se e o utilizador recebe a causa", async () => {
  const env = setup();
  const v = await uploaded(env);
  const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_color", params: { preset: "sepia" } });
  await env.runDeferred();
  await env.svc.handleResult({ jobId: job._id, type: "error", error: { code: "out_of_memory", message: "Falha de processamento por falta de recursos" } });
  const j = env.jobs.get(job._id);
  assert.equal(j.status, "failed");
  assert.equal(j.error_code, "out_of_memory");
  assert.equal(env.state.quota, 5);
  assert.equal((await env.svc.getVideo("u1", "p1", v._id)).versions.length, 1);
  assert.ok(env.ws.some((m) => m.job.status === "failed" && /recursos/.test(m.job.error_message)));
});

test("TST-QUOTA-03 sem operações disponíveis nenhum trabalho é criado", async () => {
  const env = setup({ quota: 0 });
  const v = await uploaded(env);
  await assert.rejects(env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } }), (e) => e.code === "quota_exceeded");
  assert.equal(env.jobs.size, 0);
});

test("TST-QUOTA-04 anónimo e Premium não consomem o contador", async () => {
  for (const type of ["anonymous", "premium"]) {
    const env = setup({ type });
    const v = await uploaded(env);
    await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_speed", params: { factor: 2 } });
    assert.equal(env.state.reserved, 0);
  }
});

test("TST-STATUS-06 um trabalho de cada vez por vídeo", async () => {
  const env = setup();
  const v = await uploaded(env);
  await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } });
  await assert.rejects(env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } }), (e) => e.status === 409);
  await assert.rejects(env.svc.setActive({ owner: "u1", project: "p1", videoId: v._id, to: "original" }), (e) => e.status === 409);
});

test("TST-STATUS-07 cancelar: estado Cancelado, quota devolvida, ficheiro CANCEL para o worker", async () => {
  const env = setup();
  const v = await uploaded(env);
  const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } });
  await env.runDeferred();
  const dir = env.published[0].parameters.workDir;
  const res = await env.svc.cancelJob({ owner: "u1", project: "p1", jobId: job._id });
  assert.equal(res.status, "cancelled");
  assert.equal(env.state.quota, 5);
  assert.ok(fs.existsSync(path.join(dir, "CANCEL")));
  // resultado tardio do worker é ignorado e a pasta é limpa
  await env.svc.handleResult({ jobId: job._id, type: "success", output: { videoURI: path.join(dir, "output.mp4") } });
  assert.equal((await env.svc.getVideo("u1", "p1", v._id)).versions.length, 1);
  assert.equal(fs.existsSync(dir), false);
  await assert.rejects(env.svc.cancelJob({ owner: "u1", project: "p1", jobId: job._id }), (e) => e.status === 409);
});

test("TST-STATUS-08 cancelar antes da cópia: o pedido não chega ao worker", async () => {
  const env = setup();
  const v = await uploaded(env);
  const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } });
  await env.svc.cancelJob({ owner: "u1", project: "p1", jobId: job._id });
  await env.runDeferred();
  assert.equal(env.published.length, 0);
});

test("TST-RESULT-01 Reverter e Reset entre versões", async () => {
  const env = setup();
  const v = await uploaded(env);
  for (const p of [{ start: 1, end: 10 }, { start: 1, end: 3 }]) {
    const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: p });
    await env.runDeferred();
    const out = env.published[env.published.length - 1].parameters.outputVideoURI;
    fs.writeFileSync(out, "x");
    await env.svc.handleResult({ jobId: job._id, type: "success", output: { videoURI: out, info: { duration: 4, width: 1280, height: 720, fps: 30 } } });
  }
  let cur = await env.svc.getVideo("u1", "p1", v._id);
  assert.equal(cur.versions.length, 3);
  const [v1, v2] = cur.versions;
  cur = await env.svc.setActive({ owner: "u1", project: "p1", videoId: v._id, to: "previous" });
  assert.equal(cur.active_version, v2._id);
  cur = await env.svc.setActive({ owner: "u1", project: "p1", videoId: v._id, to: "original" });
  assert.equal(cur.active_version, v1._id);
  await assert.rejects(env.svc.setActive({ owner: "u1", project: "p1", videoId: v._id, to: "previous" }), (e) => e.code === "no_previous");
});

test("TST-COL-07 LUT: só Premium, validado e guardado; trabalho recebe o caminho", async () => {
  const free = setup({ type: "free" });
  await assert.rejects(free.svc.uploadLut({ callerId: "u1", file: { buffer: Buffer.from("x") } }), (e) => e.code === "lut_premium");
  const env = setup({ type: "premium" });
  await assert.rejects(env.svc.uploadLut({ callerId: "u1", file: { buffer: Buffer.from("LUT_3D_SIZE 20\n") } }), (e) => e.code === "invalid_lut");
  const rows = Array.from({ length: 17 ** 3 }, () => "0.5 0.5 0.5").join("\n");
  const { lutId } = await env.svc.uploadLut({ callerId: "u1", file: { buffer: Buffer.from(`LUT_3D_SIZE 17\n${rows}`) } });
  const v = await uploaded(env);
  await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_color", params: { lutId } });
  await env.runDeferred();
  assert.ok(fs.existsSync(env.published[0].parameters.op.lutPath));
});

test("trabalho de outro projeto não é visível nem cancelável", async () => {
  const env = setup();
  const v = await uploaded(env);
  const job = await env.svc.createJob({ ...ctxBase, videoId: v._id, procedure: "video_trim", params: { start: 0, end: 2 } });
  await assert.rejects(env.svc.getJob("u1", "outro", job._id), (e) => e.status === 404);
  await assert.rejects(env.svc.cancelJob({ owner: "u2", project: "p1", jobId: job._id }), (e) => e.status === 404);
});
