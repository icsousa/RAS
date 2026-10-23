// Adaptadores reais das dependências do serviço de vídeo: MongoDB, armazenamento (img_storage/S3),
// microserviço users (perfil e quota) e RabbitMQ.
const fs = require("fs");
const https = require("https");
const axios = require("axios");
const mongoose = require("mongoose");
const FormData = require("form-data");

const Video = require("../models/video");
const VideoJob = require("../models/videoJob");
const { get_image_internal_url, get_image_public_url, post_image, delete_image } = require("../utils/imageStorage");
const queue = require("../utils/videoQueue");
const probe = require("../utils/videoProbe");

const users_ms = "https://users:10001/";
const httpsAgent = new https.Agent({ rejectUnauthorized: false }); // mesmo comportamento do resto do serviço (ver T-09)

const repo = {
  newId: () => new mongoose.Types.ObjectId(),
  createVideo: (doc) => Video.create(doc),
  getVideo: (owner, project, id) =>
    mongoose.isValidObjectId(id) ? Video.findOne({ _id: id, user_id: owner, project_id: project }).exec() : null,
  getVideoById: (id) => Video.findById(id).exec(),
  listVideos: (owner, project) => Video.find({ user_id: owner, project_id: project }).sort({ _id: 1 }).exec(),
  saveVideo: (video) => video.save(),
  deleteVideo: (id) => Video.deleteOne({ _id: id }).exec(),
  createJob: (doc) => VideoJob.create(doc),
  getJob: (id) => (mongoose.isValidObjectId(id) ? VideoJob.findById(id).exec() : null),
  saveJob: (job) => job.save(),
  findActiveJob: (videoId) => VideoJob.findOne({ video_id: videoId, status: { $in: ["queued", "processing"] } }).exec(),
  listJobs: (videoId) => VideoJob.find({ video_id: videoId }).sort({ createdAt: -1 }).limit(50).exec(),
};

const storage = {
  async upload(owner, project, stage, filePath, filename, mime) {
    const data = new FormData();
    data.append("file", fs.createReadStream(filePath), { filename, contentType: mime });
    const resp = await post_image(owner, project, stage, data);
    const parts = resp.data.data.imageKey.split("/");
    return parts[parts.length - 1];
  },
  async download(owner, project, stage, key, dest) {
    const { data } = await get_image_internal_url(owner, project, stage, key);
    const resp = await axios.get(data.url, { responseType: "stream" });
    await new Promise((resolve, reject) => {
      const w = fs.createWriteStream(dest);
      w.on("finish", resolve);
      w.on("error", reject);
      resp.data.on("error", reject);
      resp.data.pipe(w);
    });
  },
  async publicUrl(owner, project, stage, key) {
    const { data } = await get_image_public_url(owner, project, stage, key);
    return data.url;
  },
  remove: (owner, project, stage, key) => delete_image(owner, project, stage, key),
};

const users = {
  async type(id) {
    const { data } = await axios.get(`${users_ms}${id}/type`, { httpsAgent });
    return data.type;
  },
  // Reserva uma operação do limite diário (endpoint existente da baseline).
  async reserve(id) {
    try {
      const { data } = await axios.get(`${users_ms}${id}/process/1`, { httpsAgent });
      return data === true;
    } catch (e) {
      if (e.response && e.response.status === 701) return false;
      throw e;
    }
  },
  refund: (id) => axios.post(`${users_ms}${id}/process/refund/1`, {}, { httpsAgent }),
};

module.exports = { repo, storage, users, queue, probe };
