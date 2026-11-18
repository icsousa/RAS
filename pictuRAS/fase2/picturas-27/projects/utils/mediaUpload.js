// RNF-01 (large file upload): helpers to receive a video without holding it
// in memory. The multipart body is streamed to a temporary file, the profile
// size limit is enforced while (or before) the body is read, and the file is
// hashed and forwarded to storage as streams.
//
// Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const multer = require("multer");
const { v4: uuidv4 } = require("uuid");

const UPLOAD_DIR = process.env.UPLOAD_TMP_DIR || path.join(os.tmpdir(), "picturas-uploads");

// Room for the multipart boundaries and part headers around the file
const MULTIPART_OVERHEAD = 1024 * 1024;

// True when the declared request size can only hold a file over the limit,
// so the request can be refused before reading the body.
function exceedsLimit(contentLength, maxBytes) {
  const len = Number(contentLength);
  return Number.isFinite(len) && len > maxBytes + MULTIPART_OVERHEAD;
}

// multer middleware that writes the single file `field` to UPLOAD_DIR and
// stops with LIMIT_FILE_SIZE as soon as the file passes `maxBytes`.
function diskUpload(field, maxBytes) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const storage = multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname || "")}`),
  });
  return multer({ storage, limits: { fileSize: maxBytes, files: 1 } }).single(field);
}

// sha256 of a file, read in chunks
function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    fs.createReadStream(filePath)
      .on("data", (chunk) => hash.update(chunk))
      .on("error", reject)
      .on("end", () => resolve(hash.digest("hex")));
  });
}

// sha256 of an uploaded file, whether multer kept it on disk or in memory
function sha256Upload(file) {
  if (file.path) return sha256File(file.path);
  return Promise.resolve(crypto.createHash("sha256").update(file.buffer).digest("hex"));
}

// Body to append to a FormData: a read stream for files on disk
function uploadBody(file) {
  return file.path ? fs.createReadStream(file.path) : file.buffer;
}

// Deletes the temporary file of an upload (no-op for in-memory files)
function removeUpload(file) {
  if (file && file.path) fs.rm(file.path, { force: true }, () => {});
}

module.exports = {
  UPLOAD_DIR,
  MULTIPART_OVERHEAD,
  exceedsLimit,
  diskUpload,
  sha256File,
  sha256Upload,
  uploadBody,
  removeUpload,
};
