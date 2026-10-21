// Instância única do serviço de vídeo, com as dependências reais.
const { createVideoService } = require("./videoService");
const adapters = require("./videoAdapters");

module.exports = createVideoService({ ...adapters, dataRoot: process.env.VIDEO_DATA_ROOT || "/app/images" });
