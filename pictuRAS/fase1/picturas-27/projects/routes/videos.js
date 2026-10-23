// API REST de vídeo do serviço projects (Fase 1 — MVP de vídeo).
// Montada antes do router de projetos; reutiliza a autenticação por partilha e o limite de editores.
const express = require("express");
const multer = require("multer");

const Project = require("../controllers/project");
const { getCallerId } = require("../utils/caller");
const { checkSharePermission, requireEditPermission } = require("../middleware/shareAuth");
const enforcePresenceLimit = require("../middleware/enforcePresenceLimit");
const { VideoRuleError, parseSubtitles } = require("../utils/videoRules");

const MAX_UPLOAD_MB = Number(process.env.VIDEO_MAX_UPLOAD_MB || 500);

function videosRouter(service) {
  const router = express.Router();
  const uploadVideo = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 } });
  const uploadSmall = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

  const handle = (fn) => async (req, res) => {
    try {
      const out = await fn(req, res);
      if (!res.headersSent) res.status(out === undefined ? 204 : req.method === "POST" ? 201 : 200).json(out);
    } catch (e) {
      if (e instanceof VideoRuleError) return res.status(e.status).json(e.toJSON());
      console.error("[video] erro:", e);
      res.status(500).json({ code: "server_error", message: "Erro interno no serviço de vídeo." });
    }
  };

  async function loadProject(req, res, next) {
    try {
      const project = req.sharedProject || (await Project.getOne(req.params.user, req.params.project));
      if (!project) return res.status(404).json({ code: "not_found", message: "Projeto não encontrado." });
      req.callerId = getCallerId(req) || req.params.user;
      next();
    } catch (_) {
      res.status(404).json({ code: "not_found", message: "Projeto não encontrado." });
    }
  }

  const read = [checkSharePermission, loadProject];
  const edit = [checkSharePermission, requireEditPermission, enforcePresenceLimit, loadProject];
  const ctx = (req) => ({ owner: req.params.user, project: req.params.project, callerId: req.callerId });

  const multerErrors = (mw) => (req, res, next) =>
    mw(req, res, (err) => {
      if (!err) return next();
      if (err.code === "LIMIT_FILE_SIZE") {
        return res.status(413).json({ code: "file_too_large", message: `O ficheiro excede o máximo de ${MAX_UPLOAD_MB} MB.` });
      }
      return res.status(400).json({ code: "upload_error", message: err.message });
    });

  // Perfil e limites de vídeo de quem está a usar (para a interface restringir os controlos)
  router.get("/:user/:project/videos/limits", read, handle((req) => service.profile(req.callerId)));

  router.get("/:user/:project/videos", read, handle((req) => service.listVideos(req.params.user, req.params.project)));

  router.post(
    "/:user/:project/videos",
    edit,
    multerErrors(uploadVideo.single("video")),
    handle((req) => service.uploadVideo({ ...ctx(req), file: req.file })),
  );

  // Rotas fixas antes de /:video
  router.post(
    "/:user/:project/videos/luts",
    edit,
    multerErrors(uploadSmall.single("lut")),
    handle((req) => service.uploadLut({ callerId: req.callerId, file: req.file })),
  );

  router.post(
    "/:user/:project/videos/subtitles/parse",
    edit,
    multerErrors(uploadSmall.single("subtitles")),
    handle((req) => {
      if (!req.file) throw new VideoRuleError(400, "no_file", "Nenhum ficheiro de legendas recebido.");
      return { blocks: parseSubtitles(req.file.buffer) };
    }),
  );

  router.get("/:user/:project/videos/jobs/:job", read, handle((req) => service.getJob(req.params.user, req.params.project, req.params.job)));

  router.post(
    "/:user/:project/videos/jobs/:job/cancel",
    edit,
    handle((req) => service.cancelJob({ owner: req.params.user, project: req.params.project, jobId: req.params.job })),
  );

  router.get("/:user/:project/videos/:video", read, handle((req) => service.getVideo(req.params.user, req.params.project, req.params.video)));

  router.delete(
    "/:user/:project/videos/:video",
    edit,
    handle((req) => service.deleteVideo({ owner: req.params.user, project: req.params.project, videoId: req.params.video })),
  );

  router.get("/:user/:project/videos/:video/jobs", read, handle((req) => service.listJobs(req.params.user, req.params.project, req.params.video)));

  router.post(
    "/:user/:project/videos/:video/jobs",
    edit,
    handle((req) =>
      service.createJob({ ...ctx(req), videoId: req.params.video, procedure: req.body?.procedure, params: req.body?.params }),
    ),
  );

  // Reverter (versão anterior), Reset (original) ou ativar uma versão concreta (REQ-VID-RESULT-002)
  router.post(
    "/:user/:project/videos/:video/active",
    edit,
    handle((req) =>
      service.setActive({ owner: req.params.user, project: req.params.project, videoId: req.params.video, to: req.body?.to }),
    ),
  );

  return router;
}

module.exports = { videosRouter };
