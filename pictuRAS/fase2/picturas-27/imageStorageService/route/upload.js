const express = require("express");
const fs = require("fs");
const os = require("os");
const path = require("path");
const multer = require("multer");
const uploadImage = require("../services/uploadImage");

const router = express.Router();

// RNF-01: files are written to a temporary file as they arrive and sent to
// S3 as a stream (multipart), instead of being held in memory.
const UPLOAD_DIR = process.env.UPLOAD_TMP_DIR || path.join(os.tmpdir(), "picturas-storage");
fs.mkdirSync(UPLOAD_DIR, { recursive: true });
const upload = multer({ storage: multer.diskStorage({ destination: UPLOAD_DIR }) });

router.post(
  "/:userId/:projectId/:stage",
  upload.single("file"),
  async (req, res) => {
    const { userId, projectId, stage } = req.params;

    const allowedStages = require("../utils/stages");

    if (!allowedStages.includes(stage)) {
      if (req.file && req.file.path) fs.rm(req.file.path, { force: true }, () => {});
      return res.status(400).json({
        error: "O estágio deve ser src, preview, preview_cache ou out.",
      });
    }


    try {
      const result = await uploadImage(userId, projectId, req.file, stage);
      res
        .status(201)
        .json({ message: "Imagem enviada com sucesso!", data: result });
    } catch (error) {
      res.status(500).json({ error: error.message });
    } finally {
      if (req.file && req.file.path) fs.rm(req.file.path, { force: true }, () => {});
    }
  },
);

module.exports = router;
