// Ciclo de vida dos vídeos e dos trabalhos de processamento (Fase 1 — MVP de vídeo).
//
// As dependências (repositório, armazenamento, users-ms, filas, ffprobe) são injetadas,
// para que a lógica possa ser testada sem MongoDB, S3 nem RabbitMQ (test/videoService.test.js).
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const R = require("../utils/videoRules");

const ACTIVE = ["queued", "processing"];
const FINAL = ["completed", "failed", "cancelled"];

function createVideoService(deps) {
  const { repo, storage, users, queue, probe } = deps;
  const dataRoot = deps.dataRoot || "/app/images";
  const workRoot = path.join(dataRoot, "videos");
  const lutRoot = path.join(dataRoot, "luts");
  const speedTimeoutSec = Number(process.env.VIDEO_SPEED_TIMEOUT_SEC || 120); // REQ-VID-SPD-006
  const defer = deps.defer || ((fn) => setImmediate(fn));
  const log = deps.log || console;

  const fail = (status, code, message, requirement) => new R.VideoRuleError(status, code, message, requirement);

  // ---------------------------------------------------------------- utilitários
  function activeVersion(video) {
    return video.versions.find((v) => String(v._id) === String(video.active_version)) || video.versions[video.versions.length - 1];
  }

  function jobSummary(job) {
    return {
      _id: String(job._id),
      video_id: String(job.video_id),
      procedure: job.procedure,
      params: job.params,
      status: job.status,
      progress: job.progress,
      error_code: job.error_code,
      error_message: job.error_message,
      warnings: job.warnings || [],
      meta: job.meta || {},
      result_version: job.result_version ? String(job.result_version) : null,
      created_at: job.createdAt || job.created_at || null,
      finished_at: job.finished_at || null,
    };
  }

  async function notify(job) {
    try {
      await queue.publishWs({
        type: "video-job",
        messageId: `video-job-update-${crypto.randomUUID()}`,
        timestamp: new Date().toISOString(),
        user: String(job.runner_id),
        ownerId: String(job.owner_id),
        projectId: String(job.project_id),
        job: jobSummary(job),
      });
    } catch (e) {
      log.error("[video] falha ao notificar o browser:", e.message);
    }
  }

  function rmrf(dir) {
    if (dir && path.resolve(dir).startsWith(workRoot + path.sep)) fs.rmSync(dir, { recursive: true, force: true });
  }

  async function refund(job) {
    if (!job.quota_reserved) return;
    try {
      await users.refund(job.runner_id);
    } catch (e) {
      log.error("[video] falha a devolver a operação ao utilizador:", e.message);
    }
    job.quota_reserved = false;
  }

  async function versionWithUrl(owner, project, v) {
    let url = null;
    try {
      url = await storage.publicUrl(owner, project, v.stage, v.key);
    } catch (_) {
      /* sem URL: o frontend mostra erro de carregamento */
    }
    const { keyframes, ...rest } = v.toObject ? v.toObject() : v;
    return { ...rest, _id: String(v._id), parent_id: v.parent_id ? String(v.parent_id) : null, keyframe_count: (keyframes || []).length, keyframes, url };
  }

  async function view(video, { withVersions = true } = {}) {
    const owner = String(video.user_id);
    const project = String(video.project_id);
    const active = activeVersion(video);
    const activeJob = await repo.findActiveJob(video._id);
    return {
      _id: String(video._id),
      name: video.name,
      project_id: project,
      user_id: owner,
      active_version: active ? String(active._id) : null,
      active: active ? await versionWithUrl(owner, project, active) : null,
      versions: withVersions ? await Promise.all(video.versions.map((v) => versionWithUrl(owner, project, v))) : undefined,
      active_job: activeJob ? jobSummary(activeJob) : null,
      created_at: video.created_at,
    };
  }

  async function loadVideo(owner, project, videoId) {
    const video = await repo.getVideo(owner, project, videoId);
    if (!video) throw fail(404, "not_found", "Vídeo não encontrado.");
    return video;
  }

  // ---------------------------------------------------------------- submissão (REQ-VID-SUBMIT-001/002)
  async function uploadVideo({ owner, project, callerId, file }) {
    if (!file || !file.buffer || !file.buffer.length) throw fail(400, "no_file", "Nenhum ficheiro de vídeo recebido.");
    const type = await users.type(callerId);
    const uploads = path.join(workRoot, "uploads");
    fs.mkdirSync(uploads, { recursive: true });
    const ext = (path.extname(file.originalname || "") || ".mp4").toLowerCase().replace(/[^.a-z0-9]/g, "");
    const tmp = path.join(uploads, `${crypto.randomUUID()}${ext}`);
    fs.writeFileSync(tmp, file.buffer);
    try {
      let info;
      try {
        info = await probe.probeVideo(tmp);
      } catch (_) {
        throw fail(400, "unsupported_format", "Ficheiro não reconhecido como vídeo. Use MP4 ou MOV (H.264/AAC).", "REQ-VID-SUBMIT-001");
      }
      R.validateSubmission(info, type);
      const keyframes = await probe.keyframeTimes(tmp).catch(() => []);
      const name = path.basename(file.originalname || "video.mp4");
      const mime = /quicktime/.test(file.mimetype) ? "video/quicktime" : "video/mp4";
      const key = await storage.upload(owner, project, "src", tmp, name, mime);
      const versionId = repo.newId();
      const video = await repo.createVideo({
        user_id: owner,
        project_id: project,
        name,
        active_version: versionId,
        versions: [{ _id: versionId, key, stage: "src", mime, size: info.size, keyframes, ...pickInfo(info) }],
      });
      return view(video);
    } finally {
      fs.rmSync(tmp, { force: true });
    }
  }

  function pickInfo(info) {
    return {
      duration: info.duration,
      width: info.width,
      height: info.height,
      fps: info.fps,
      has_audio: !!info.has_audio,
      sample_rate: info.sample_rate || null,
      video_codec: info.video_codec || null,
      audio_codec: info.audio_codec || null,
      subtitle_streams: info.subtitle_streams || 0,
    };
  }

  // ---------------------------------------------------------------- criação de trabalhos
  async function createJob({ owner, project, videoId, callerId, procedure, params }) {
    const video = await loadVideo(owner, project, videoId);
    const source = activeVersion(video);
    // Um trabalho de cada vez por vídeo (REQ-VID-STATUS-004)
    if (await repo.findActiveJob(video._id)) {
      throw fail(409, "job_in_progress", "Já existe uma operação em curso neste vídeo. Aguarde que termine ou cancele-a.", "REQ-VID-STATUS-004");
    }
    const type = await users.type(callerId);
    const { op } = R.validateJob(procedure, params, type, source);

    if (op.lutId && !fs.existsSync(path.join(lutRoot, String(callerId), `${op.lutId}.cube`))) {
      throw fail(400, "invalid_lut", "LUT não encontrado. Importe o ficheiro novamente.", "REQ-VID-COL-002");
    }

    // Quota (RNG-01): reserva-se ao criar; devolve-se se o trabalho falhar ou for cancelado.
    let reserved = false;
    if (R.profileFor(type).countsQuota) {
      const ok = await users.reserve(callerId);
      if (!ok) throw fail(403, "quota_exceeded", "Atingiu o limite diário de operações. Volte amanhã ou mude para Premium.", "REQ-VID-QUOTA-002");
      reserved = true;
    }

    let job;
    try {
      job = await repo.createJob({
        video_id: video._id,
        project_id: project,
        owner_id: owner,
        runner_id: String(callerId),
        runner_type: type,
        source_version: source._id,
        procedure,
        params: op,
        status: "queued",
        progress: 0,
        quota_reserved: reserved,
      });
    } catch (e) {
      if (reserved) await users.refund(callerId).catch(() => {});
      throw e;
    }
    job.work_dir = path.join(workRoot, String(job._id));
    await repo.saveJob(job);
    await notify(job);
    // A resposta ao pedido não espera pela cópia do vídeo (REQ-VID-PERF-001, DQ-001).
    defer(() => prepareAndPublish(String(job._id)).catch((e) => log.error("[video] prepare:", e)));
    return jobSummary(job);
  }

  async function prepareAndPublish(jobId) {
    let job = await repo.getJob(jobId);
    if (!job) return;
    if (job.status !== "queued") {
      rmrf(job.work_dir); // cancelado antes de começar
      return;
    }
    const video = await repo.getVideoById(job.video_id);
    const source = video && video.versions.find((v) => String(v._id) === String(job.source_version));
    try {
      if (!source) throw new Error("versão de origem inexistente");
      fs.mkdirSync(job.work_dir, { recursive: true });
      const input = path.join(job.work_dir, `input${source.stage === "src" && /quicktime/.test(source.mime) ? ".mov" : ".mp4"}`);
      await storage.download(String(job.owner_id), String(job.project_id), source.stage, source.key, input);

      job = await repo.getJob(jobId);
      if (!job || job.status !== "queued") {
        // cancelado durante a cópia
        rmrf(job ? job.work_dir : null);
        return;
      }
      const profile = R.profileFor(job.runner_type);
      const op = { ...job.params };
      if (op.lutId) {
        const lutSrc = path.join(lutRoot, String(job.runner_id), `${op.lutId}.cube`);
        op.lutPath = path.join(job.work_dir, "lut.cube");
        fs.copyFileSync(lutSrc, op.lutPath);
      }
      await queue.publishRequest({
        messageId: `video-job-${jobId}`,
        jobId: String(jobId),
        timestamp: new Date().toISOString(),
        procedure: job.procedure,
        parameters: {
          inputVideoURI: input,
          outputVideoURI: path.join(job.work_dir, "output.mp4"),
          workDir: job.work_dir,
          maxShortSide: profile.maxShortSide,
          timeoutSec: job.procedure === "video_speed" ? speedTimeoutSec : undefined,
          op,
        },
      });
    } catch (e) {
      log.error("[video] falha a preparar o trabalho:", e.message);
      await finish(jobId, "failed", { error_code: "storage_error", error_message: "Não foi possível obter o vídeo de origem." });
    }
  }

  // Termina um trabalho, devolve a quota se não concluído e notifica (RNG-06).
  async function finish(jobId, status, fields = {}) {
    const job = await repo.getJob(jobId);
    if (!job || FINAL.includes(job.status)) return job;
    Object.assign(job, fields, { status, finished_at: new Date() });
    if (status !== "completed") await refund(job);
    await repo.saveJob(job);
    if (status !== "cancelled") rmrf(job.work_dir); // num cancelamento, o worker ainda pode estar a ler a pasta
    await notify(job);
    return job;
  }

  // ---------------------------------------------------------------- resultados do worker
  async function handleResult(msg) {
    const job = await repo.getJob(msg.jobId);
    if (!job) return;
    if (FINAL.includes(job.status)) {
      // Mensagem tardia (e.g. depois de um cancelamento): só limpar a pasta quando o worker acaba.
      if (msg.type !== "progress") rmrf(job.work_dir);
      return;
    }

    if (msg.type === "progress") {
      job.status = "processing";
      job.progress = Math.max(job.progress || 0, Math.min(99, Number(msg.progress) || 0));
      if (!job.started_at) job.started_at = new Date();
      await repo.saveJob(job);
      await notify(job);
      return;
    }

    if (msg.type === "error") {
      const code = msg.error?.code || "processing_error";
      await finish(job._id, code === "cancelled" ? "cancelled" : "failed", {
        error_code: code,
        error_message: msg.error?.message || "Erro no processamento do vídeo.",
      });
      if (code === "cancelled") rmrf(job.work_dir);
      return;
    }

    if (msg.type === "success") {
      try {
        const out = msg.output.videoURI;
        if (!path.resolve(out).startsWith(path.resolve(job.work_dir) + path.sep)) throw new Error("caminho de saída inválido");
        const info = msg.output.info || (await probe.probeVideo(out));
        const keyframes = await probe.keyframeTimes(out).catch(() => []);
        const video = await repo.getVideoById(job.video_id);
        const name = `${path.parse(video.name).name}-${job.procedure.replace("video_", "")}.mp4`;
        const key = await storage.upload(String(job.owner_id), String(job.project_id), "out", out, name, "video/mp4");
        const versionId = repo.newId();
        video.versions.push({
          _id: versionId,
          key,
          stage: "out",
          mime: "video/mp4",
          size: info.size || 0,
          keyframes,
          ...pickInfo(info),
          parent_id: job.source_version,
          job_id: job._id,
          procedure: job.procedure,
          params: job.params,
          created_at: new Date(),
        });
        video.active_version = versionId; // RNG-05: nova versão ativa; a origem mantém-se
        await repo.saveVideo(video);
        await finish(job._id, "completed", {
          progress: 100,
          warnings: msg.warnings || [],
          meta: msg.meta || {},
          result_version: versionId,
        });
      } catch (e) {
        log.error("[video] falha a guardar o resultado:", e.message);
        await finish(job._id, "failed", { error_code: "storage_error", error_message: "Não foi possível guardar o vídeo resultado." });
      }
    }
  }

  // ---------------------------------------------------------------- cancelamento (REQ-VID-STATUS-003)
  async function cancelJob({ owner, project, jobId }) {
    const job = await repo.getJob(jobId);
    if (!job || String(job.owner_id) !== String(owner) || String(job.project_id) !== String(project)) {
      throw fail(404, "not_found", "Trabalho não encontrado.");
    }
    if (!ACTIVE.includes(job.status)) throw fail(409, "not_active", "O trabalho já terminou.", "REQ-VID-STATUS-003");
    if (job.work_dir) {
      fs.mkdirSync(job.work_dir, { recursive: true });
      fs.writeFileSync(path.join(job.work_dir, "CANCEL"), new Date().toISOString());
    }
    const done = await finish(job._id, "cancelled", { error_code: "cancelled", error_message: "Cancelado pelo utilizador." });
    return jobSummary(done);
  }

  // ---------------------------------------------------------------- versões (REQ-VID-RESULT-001/002)
  async function setActive({ owner, project, videoId, to }) {
    const video = await loadVideo(owner, project, videoId);
    if (await repo.findActiveJob(video._id)) throw fail(409, "job_in_progress", "Há uma operação em curso neste vídeo.", "REQ-VID-STATUS-004");
    const current = activeVersion(video);
    let target;
    if (to === "previous") {
      target = current.parent_id && video.versions.find((v) => String(v._id) === String(current.parent_id));
      if (!target) throw fail(400, "no_previous", "Não existem versões anteriores deste vídeo.", "REQ-VID-RESULT-002");
    } else if (to === "original") {
      target = video.versions[0];
    } else {
      target = video.versions.find((v) => String(v._id) === String(to));
      if (!target) throw fail(404, "not_found", "Versão não encontrada.");
    }
    video.active_version = target._id;
    await repo.saveVideo(video);
    return view(video);
  }

  async function deleteVideo({ owner, project, videoId }) {
    const video = await loadVideo(owner, project, videoId);
    if (await repo.findActiveJob(video._id)) throw fail(409, "job_in_progress", "Há uma operação em curso neste vídeo.", "REQ-VID-STATUS-004");
    for (const v of video.versions) {
      await storage.remove(owner, project, v.stage, v.key).catch(() => {});
    }
    await repo.deleteVideo(video._id);
  }

  async function deleteProjectVideos(owner, project) {
    for (const v of await repo.listVideos(owner, project)) {
      for (const ver of v.versions) await storage.remove(owner, project, ver.stage, ver.key).catch(() => {});
      await repo.deleteVideo(v._id);
    }
  }

  // ---------------------------------------------------------------- LUT 3D (REQ-VID-COL-002/009)
  async function uploadLut({ callerId, file }) {
    const type = await users.type(callerId);
    if (!R.profileFor(type).lut) throw fail(403, "lut_premium", "A importação de LUTs 3D personalizados é exclusiva do perfil Premium.", "REQ-VID-COL-002");
    if (!file || !file.buffer) throw fail(400, "no_file", "Nenhum ficheiro .cube recebido.");
    let text;
    try {
      text = new TextDecoder("utf-8", { fatal: true }).decode(file.buffer);
    } catch (_) {
      throw fail(400, "invalid_lut", "Ficheiro LUT inválido ou corrompido.", "REQ-VID-COL-009");
    }
    const size = R.validateCube(text);
    const id = crypto.randomUUID();
    const dir = path.join(lutRoot, String(callerId));
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, `${id}.cube`), text);
    return { lutId: id, size, name: file.originalname || "lut.cube" };
  }

  return {
    uploadVideo,
    createJob,
    prepareAndPublish,
    handleResult,
    cancelJob,
    setActive,
    deleteVideo,
    deleteProjectVideos,
    uploadLut,
    listVideos: async (owner, project) => Promise.all((await repo.listVideos(owner, project)).map((v) => view(v, { withVersions: false }))),
    getVideo: async (owner, project, videoId) => view(await loadVideo(owner, project, videoId)),
    listJobs: async (owner, project, videoId) => {
      const video = await loadVideo(owner, project, videoId);
      return (await repo.listJobs(video._id)).map(jobSummary);
    },
    getJob: async (owner, project, jobId) => {
      const job = await repo.getJob(jobId);
      if (!job || String(job.owner_id) !== String(owner) || String(job.project_id) !== String(project)) throw fail(404, "not_found", "Trabalho não encontrado.");
      return jobSummary(job);
    },
    profile: async (callerId) => R.publicProfile(await users.type(callerId)),
  };
}

module.exports = { createVideoService };
