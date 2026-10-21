// Encaminhamento das rotas de vídeo para o serviço projects (Fase 1 — MVP de vídeo).
// Montado em /projects antes do router de projetos.
const express = require("express");
const axios = require("axios");
const https = require("https");
const multer = require("multer");
const FormData = require("form-data");
const auth = require("../auth/auth");

const router = express.Router();
const projectsURL = "https://projects:9001/";
const httpsAgent = new https.Agent({ rejectUnauthorized: false });
const MAX_UPLOAD_MB = Number(process.env.VIDEO_MAX_UPLOAD_MB || 500);
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 } });

function forward(req, res, { method, path, data, headers = {} }) {
  const ownerId = req.query.owner || req.params.user;
  const callerId = req.authUserId || req.params.user;
  return axios({
    method,
    url: projectsURL + `${ownerId}/${req.params.project}/videos${path}`,
    data,
    httpsAgent,
    params: req.query.share ? { share: req.query.share } : undefined,
    headers: { ...headers, Authorization: req.headers["authorization"], "X-Caller-Id": callerId },
    maxBodyLength: Infinity,
    maxContentLength: Infinity,
    validateStatus: () => true,
  })
    .then((resp) => (resp.status === 204 ? res.sendStatus(204) : res.status(resp.status).json(resp.data)))
    .catch((err) => {
      console.error("[API-GW][video]", err.message);
      res.status(502).json({ code: "projects_unavailable", message: "Serviço de projetos indisponível." });
    });
}

function json(method, path) {
  return [auth.checkToken, (req, res) => forward(req, res, { method, path: path(req), data: method === "get" || method === "delete" ? undefined : req.body })];
}

function multipart(field, path) {
  return [
    auth.checkToken, // antes do multer: não aceitar uploads grandes sem autenticação
    (req, res, next) =>
      upload.single(field)(req, res, (err) => {
        if (err && err.code === "LIMIT_FILE_SIZE") {
          return res.status(413).json({ code: "file_too_large", message: `O ficheiro excede o máximo de ${MAX_UPLOAD_MB} MB.` });
        }
        if (err) return res.status(400).json({ code: "upload_error", message: err.message });
        next();
      }),
    (req, res) => {
      if (!req.file) return res.status(400).json({ code: "no_file", message: "Nenhum ficheiro recebido." });
      const data = new FormData();
      data.append(field, req.file.buffer, { filename: req.file.originalname, contentType: req.file.mimetype });
      return forward(req, res, { method: "post", path, data, headers: data.getHeaders() });
    },
  ];
}

router.get("/:user/:project/videos", ...json("get", () => ""));
router.get("/:user/:project/videos/limits", ...json("get", () => "/limits"));
router.post("/:user/:project/videos", ...multipart("video", ""));
router.post("/:user/:project/videos/luts", ...multipart("lut", "/luts"));
router.post("/:user/:project/videos/subtitles/parse", ...multipart("subtitles", "/subtitles/parse"));
router.get("/:user/:project/videos/jobs/:job", ...json("get", (r) => `/jobs/${r.params.job}`));
router.post("/:user/:project/videos/jobs/:job/cancel", ...json("post", (r) => `/jobs/${r.params.job}/cancel`));
router.get("/:user/:project/videos/:video", ...json("get", (r) => `/${r.params.video}`));
router.delete("/:user/:project/videos/:video", ...json("delete", (r) => `/${r.params.video}`));
router.get("/:user/:project/videos/:video/jobs", ...json("get", (r) => `/${r.params.video}/jobs`));
router.post("/:user/:project/videos/:video/jobs", ...json("post", (r) => `/${r.params.video}/jobs`));
router.post("/:user/:project/videos/:video/active", ...json("post", (r) => `/${r.params.video}/active`));

module.exports = router;
