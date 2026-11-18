// Regression tests for the RNF-01 refactoring (large file upload).
// Run inside the container: docker compose exec projects node --test
// (needs only Node's built-in test runner and ffmpeg, both in the image).
//
// Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const {
  exceedsLimit,
  diskUpload,
  sha256Upload,
  uploadBody,
  removeUpload,
  MULTIPART_OVERHEAD,
} = require("../utils/mediaUpload");
const {
  probeVideoBuffer,
  probeVideoFile,
  validateVideo,
  uploadLimitBytes,
  sizeLimitMessage,
} = require("../utils/video");

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "rnf01-"));

function makeVideo(name, seconds = 2) {
  const out = path.join(tmp, name);
  execFileSync("ffmpeg", ["-y", "-v", "error", "-f", "lavfi", "-i",
    `testsrc=size=320x240:rate=25:duration=${seconds}`, "-c:v", "libx264",
    "-pix_fmt", "yuv420p", out]);
  return out;
}

test("the declared size refuses only requests that cannot fit the limit", () => {
  const max = 100 * 1024 * 1024;
  assert.equal(exceedsLimit(String(max), max), false);
  assert.equal(exceedsLimit(String(max + MULTIPART_OVERHEAD), max), false);
  assert.equal(exceedsLimit(String(max + MULTIPART_OVERHEAD + 1), max), true);
  // no Content-Length (chunked): decided while reading, not up front
  assert.equal(exceedsLimit(undefined, max), false);
});

test("profile limits keep the values used before the refactoring", () => {
  assert.equal(uploadLimitBytes("free"), 100 * 1024 * 1024);
  assert.equal(uploadLimitBytes("premium"), 1024 * 1024 * 1024);
  assert.equal(uploadLimitBytes("anonymous"), 0);
});

test("an oversized video is refused with the same message as before", () => {
  const meta = { video_codec: "h264", duration: 10, width: 640, height: 360,
    size_bytes: 150 * 1024 * 1024 };
  const msg = validateVideo(meta, "a.mp4", "video/mp4", "free");
  assert.equal(msg, "The video is 150.0 MB and your profile limit is 100 MB");
  assert.equal(sizeLimitMessage(meta.size_bytes, "free"), msg);
});

test("probing the file on disk gives the same metadata as probing the buffer", async () => {
  const video = makeVideo("probe.mp4");
  const buffer = fs.readFileSync(video);
  const fromBuffer = await probeVideoBuffer(buffer, "probe.mp4");
  const fromFile = await probeVideoFile(video, buffer.length);
  assert.deepEqual(fromFile, fromBuffer);
  assert.equal(fromFile.size_bytes, buffer.length);
});

test("og_sha256 is the same whether the upload is on disk or in memory", async () => {
  const video = makeVideo("hash.mp4");
  const buffer = fs.readFileSync(video);
  const expected = crypto.createHash("sha256").update(buffer).digest("hex");
  assert.equal(await sha256Upload({ path: video }), expected);
  assert.equal(await sha256Upload({ buffer }), expected);
});

test("a file on disk is forwarded as a stream, not read into memory", () => {
  const video = makeVideo("stream.mp4");
  const body = uploadBody({ path: video });
  assert.ok(body instanceof fs.ReadStream);
  body.destroy();
  const buffer = Buffer.from("x");
  assert.equal(uploadBody({ buffer }), buffer);
});

test("the temporary upload file is removed", async () => {
  const f = path.join(tmp, "to-remove.bin");
  fs.writeFileSync(f, "x");
  removeUpload({ path: f });
  await new Promise((r) => setTimeout(r, 50));
  assert.equal(fs.existsSync(f), false);
  removeUpload(undefined); // no file: no error
  removeUpload({ buffer: Buffer.from("x") });
});

// Sends `bytes` bytes as the multipart field "video" to a server that only
// runs diskUpload(maxBytes); resolves with the result of the middleware.
function uploadThrough(maxBytes, bytes) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      diskUpload("video", maxBytes)(req, res, (err) => {
        const file = req.file;
        const result = {
          error: err ? err.code : null,
          size: file ? file.size : null,
          onDisk: file ? fs.existsSync(file.path) : false,
          inMemory: file ? Buffer.isBuffer(file.buffer) : false,
        };
        removeUpload(file);
        res.setHeader("Connection", "close");
        res.end(JSON.stringify(result));
      });
    });
    server.listen(0, async () => {
      try {
        const form = new FormData();
        form.append("video", new Blob([Buffer.alloc(bytes, 1)], { type: "video/mp4" }), "v.mp4");
        const r = await fetch(`http://127.0.0.1:${server.address().port}/`, { method: "POST", body: form });
        resolve(JSON.parse(await r.text()));
      } catch (e) {
        reject(e);
      } finally {
        server.close();
      }
    });
  });
}

test("diskUpload writes the file to disk, not to memory", async () => {
  const r = await uploadThrough(5 * 1024 * 1024, 3 * 1024 * 1024);
  assert.equal(r.error, null);
  assert.equal(r.size, 3 * 1024 * 1024);
  assert.equal(r.onDisk, true);
  assert.equal(r.inMemory, false);
});

test("diskUpload stops as soon as the file passes the profile limit", async () => {
  const r = await uploadThrough(1 * 1024 * 1024, 3 * 1024 * 1024);
  assert.equal(r.error, "LIMIT_FILE_SIZE");
});

test.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
