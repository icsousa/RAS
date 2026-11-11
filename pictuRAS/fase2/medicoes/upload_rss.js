// Exploratory: peak RSS of a hop that buffers the whole upload (multer memoryStorage + FormData copy)
// vs. a hop that streams it to disk. Usage: node upload_rss.js <buffer|stream> <MB>
const http = require("http"), fs = require("fs"), os = require("os"), path = require("path");
const mode = process.argv[2], MB = +process.argv[3];
let peak = 0; const tick = setInterval(() => { peak = Math.max(peak, process.memoryUsage().rss); }, 20);
const srv = http.createServer((req, res) => {
  const t0 = Date.now();
  if (mode === "buffer") {
    const chunks = []; req.on("data", c => chunks.push(c));
    req.on("end", () => {
      const file = Buffer.concat(chunks);                 // multer memoryStorage
      const fwd = Buffer.concat([Buffer.from("--b\r\n"), file, Buffer.from("\r\n--b--")]); // FormData re-serialisation
      fs.writeFileSync(path.join(os.tmpdir(), "probe.bin"), file); // ffprobe tmp copy
      require("crypto").createHash("sha256").update(file).digest("hex");
      res.end(String(fwd.length)); done(t0);
    });
  } else {
    const h = require("crypto").createHash("sha256"); const w = fs.createWriteStream(path.join(os.tmpdir(), "probe.bin"));
    req.on("data", c => h.update(c)); req.pipe(w);
    w.on("finish", () => { h.digest("hex"); res.end("ok"); done(t0); });
  }
});
function done(t0) { setTimeout(() => { clearInterval(tick); peak = Math.max(peak, process.memoryUsage().rss);
  console.log(JSON.stringify({ mode, MB, peak_rss_MB: +(peak / 2**20).toFixed(1), ms: Date.now() - t0 })); srv.close(); }, 100); }
srv.listen(0, () => {
  const req = http.request({ port: srv.address().port, method: "POST" });
  const chunk = Buffer.alloc(1 << 20, 7); let sent = 0;
  (function write() { while (sent < MB) { sent++; if (!req.write(chunk)) return req.once("drain", write); } req.end(); })();
  req.on("response", r => r.resume());
});
