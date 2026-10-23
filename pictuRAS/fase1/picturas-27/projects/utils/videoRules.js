// Regras de negócio do vídeo (Fase 1 — MVP). Módulo puro: sem dependências externas,
// testado em projects/test/videoRules.test.js.
//
// Fonte única dos limites por perfil (RNG-01, RNG-04 e regras locais dos UC-VID).

const ALL_TOOLS = ["video_trim", "video_crop", "video_speed", "video_text", "video_color"];

const PROFILES = {
  anonymous: {
    maxDurationSec: 60,
    maxShortSide: 720,
    speed: [0.5, 2],
    tools: ["video_trim", "video_speed", "video_color"], // UC-VID-002/RN3, REQ-VID-TXT-012
    maxKeyframes: 0,
    maxTextBlocks: 0,
    softSub: false,
    lut: false,
    countsQuota: false, // RNG-01: o Anónimo não tem contador diário na baseline
  },
  free: {
    maxDurationSec: 300,
    maxShortSide: 1080,
    speed: [0.25, 4],
    tools: ALL_TOOLS,
    maxKeyframes: 5, // UC-VID-002/RN1
    maxTextBlocks: 20, // UC-VID-004/RN2
    softSub: false, // UC-VID-004/RN1
    lut: false, // UC-VID-005/RN1
    countsQuota: true, // RNG-01: 1 operação do limite diário (FREE_DAILY_OP)
  },
  premium: {
    maxDurationSec: 3600,
    maxShortSide: 2160,
    speed: [0.1, 10],
    tools: ALL_TOOLS,
    maxKeyframes: Infinity,
    maxTextBlocks: Infinity,
    softSub: true,
    lut: true,
    countsQuota: false,
  },
};

const COLOR_PRESETS = ["none", "sepia", "bw", "high_contrast", "cinematic"];
const FONTS = ["Noto Sans", "Noto Serif", "DejaVu Sans", "Liberation Sans", "Liberation Serif"];
const MIN_TRIM_SEC = 0.5; // UC-VID-001/RN2
const MIN_CROP = { w: 320, h: 240 }; // UC-VID-002/RN2

class VideoRuleError extends Error {
  constructor(status, code, message, requirement) {
    super(message);
    this.status = status;
    this.code = code;
    this.requirement = requirement;
  }
  toJSON() {
    return { code: this.code, message: this.message, requirement: this.requirement };
  }
}

function profileFor(type) {
  return PROFILES[type] || PROFILES.anonymous;
}

// JSON não representa Infinity: o frontend recebe null ("sem limite").
function publicProfile(type) {
  const p = profileFor(type);
  const out = { type: PROFILES[type] ? type : "anonymous" };
  for (const [k, v] of Object.entries(p)) out[k] = v === Infinity ? null : v;
  return out;
}

// ------------------------------------------------------------------ submissão (REQ-VID-SUBMIT-001/002)
function validateSubmission(info, type) {
  const p = profileFor(type);
  const fmt = String(info.format_name || "");
  if (!/mp4|mov/.test(fmt)) {
    throw new VideoRuleError(400, "unsupported_format", "Formato não suportado: use MP4 ou MOV.", "REQ-VID-SUBMIT-001");
  }
  if (!info.has_video || info.video_codec !== "h264") {
    throw new VideoRuleError(400, "unsupported_codec", "O vídeo tem de estar codificado em H.264.", "REQ-VID-SUBMIT-001");
  }
  if (info.has_audio && info.audio_codec !== "aac") {
    throw new VideoRuleError(400, "unsupported_codec", "O áudio tem de estar codificado em AAC.", "REQ-VID-SUBMIT-001");
  }
  if (!(info.duration > 0) || !(info.width > 0) || !(info.height > 0) || !(info.fps > 0)) {
    throw new VideoRuleError(400, "corrupt_input", "Não foi possível ler os metadados do vídeo.", "REQ-VID-SUBMIT-001");
  }
  if (info.duration > p.maxDurationSec + 0.5) {
    throw new VideoRuleError(
      403,
      "duration_limit",
      `O vídeo tem ${Math.round(info.duration)} s; o máximo do seu perfil é ${p.maxDurationSec} s.`,
      "REQ-VID-SUBMIT-002",
    );
  }
  return true;
}

// ------------------------------------------------------------------ auxiliares de validação
function num(v, name, { min = -Infinity, max = Infinity } = {}) {
  const n = typeof v === "string" && v.trim() !== "" ? Number(v) : v;
  if (typeof n !== "number" || !Number.isFinite(n) || n < min || n > max) {
    throw new VideoRuleError(400, "invalid_params", `Parâmetro '${name}' inválido.`);
  }
  return n;
}

function requireTool(p, procedure, requirement) {
  if (!p.tools.includes(procedure)) {
    throw new VideoRuleError(403, "tool_not_allowed", "Esta ferramenta não está disponível para o seu perfil. Registe-se para a usar.", requirement);
  }
}

const EPS = 1e-3;

// ------------------------------------------------------------------ validação dos trabalhos
// `video` contém os metadados da versão de origem (duration, width, height, fps, has_audio, keyframes).
// Devolve { op, expectedOutputDuration } com os parâmetros normalizados para o worker.
function validateJob(procedure, params, type, video) {
  const p = profileFor(type);
  params = params || {};
  const D = video.duration;
  switch (procedure) {
    case "video_trim": {
      requireTool(p, procedure);
      const start = num(params.start, "start", { min: 0 });
      const end = num(params.end, "end", { min: 0 });
      if (end > D + EPS) throw new VideoRuleError(400, "invalid_params", "O fim do excerto ultrapassa a duração do vídeo.", "REQ-VID-TRIM-004");
      if (start >= end || end - start < MIN_TRIM_SEC) {
        throw new VideoRuleError(400, "invalid_interval", "O instante de fim tem de ser superior ao de início e o excerto ter pelo menos 0,5 s.", "REQ-VID-TRIM-004");
      }
      const mode = params.mode === "fast" ? "fast" : "precise"; // REQ-VID-TRIM-003: preciso por omissão
      return { op: { start, end, mode }, expectedOutputDuration: end - start };
    }

    case "video_crop": {
      requireTool(p, procedure, "REQ-VID-CROP-005");
      const kfs = params.keyframes;
      if (!Array.isArray(kfs) || kfs.length < 1) throw new VideoRuleError(400, "invalid_params", "Defina pelo menos um keyframe.");
      if (kfs.length > p.maxKeyframes) {
        throw new VideoRuleError(403, "keyframe_limit", `O seu perfil permite no máximo ${p.maxKeyframes} keyframes por vídeo. Mude para Premium para keyframes ilimitados.`, "REQ-VID-CROP-010");
      }
      const minW = Math.min(MIN_CROP.w, video.width);
      const minH = Math.min(MIN_CROP.h, video.height);
      const norm = kfs
        .map((k, i) => ({
          t: num(k.t, `keyframes[${i}].t`, { min: 0, max: D + EPS }),
          x: num(k.x, `keyframes[${i}].x`, { min: 0 }),
          y: num(k.y, `keyframes[${i}].y`, { min: 0 }),
          w: num(k.w, `keyframes[${i}].w`, { min: 1 }),
          h: num(k.h, `keyframes[${i}].h`, { min: 1 }),
        }))
        .sort((a, b) => a.t - b.t);
      for (let i = 0; i < norm.length; i++) {
        const k = norm[i];
        if (k.w < minW - 0.5 || k.h < minH - 0.5) {
          throw new VideoRuleError(400, "crop_too_small", "A área de corte não pode ser inferior a 320x240 píxeis para evitar pixelização excessiva.", "REQ-VID-CROP-004");
        }
        if (k.x + k.w > video.width + 0.5 || k.y + k.h > video.height + 0.5) {
          throw new VideoRuleError(400, "invalid_params", "A moldura de um keyframe sai do fotograma.");
        }
        if (i > 0 && Math.abs(k.t - norm[i - 1].t) < EPS) {
          throw new VideoRuleError(400, "invalid_params", "Dois keyframes no mesmo instante.");
        }
      }
      const a0 = norm[0].w / norm[0].h;
      if (norm.some((k) => Math.abs(k.w / k.h - a0) / a0 > 0.02)) {
        throw new VideoRuleError(400, "invalid_params", "Todos os keyframes têm de ter o mesmo rácio de aspeto.", "REQ-VID-CROP-003");
      }
      return { op: { keyframes: norm }, expectedOutputDuration: D };
    }

    case "video_speed": {
      requireTool(p, procedure);
      const [lo, hi] = p.speed;
      const factor = num(params.factor, "factor");
      if (factor < lo - EPS || factor > hi + EPS) {
        throw new VideoRuleError(403, "speed_limit", `O seu perfil permite velocidades entre ${lo}x e ${hi}x.`, "REQ-VID-SPD-002");
      }
      let segment = null;
      let segLen = D;
      if (params.segment) {
        const s = num(params.segment.start, "segment.start", { min: 0 });
        const e = num(params.segment.end, "segment.end", { min: 0, max: D + EPS });
        if (e - s < 0.1) throw new VideoRuleError(400, "invalid_interval", "O segmento tem de ter pelo menos 0,1 s.", "REQ-VID-SPD-003");
        segment = { start: s, end: Math.min(e, D) };
        segLen = segment.end - segment.start;
      }
      const expected = D - segLen + segLen / factor;
      if (expected > p.maxDurationSec + 0.5) {
        throw new VideoRuleError(400, "duration_limit", `O vídeo resultante teria ${Math.round(expected)} s; o máximo do seu perfil é ${p.maxDurationSec} s.`, "REQ-VID-SPD-009");
      }
      return {
        op: { factor, segment, pitch: params.pitch !== false, removeAudio: params.removeAudio === true },
        expectedOutputDuration: expected,
      };
    }

    case "video_text": {
      requireTool(p, procedure, "REQ-VID-TXT-012");
      const mode = params.mode === "softsub" ? "softsub" : "hardcode";
      if (mode === "softsub" && !p.softSub) {
        throw new VideoRuleError(403, "softsub_premium", "A exportação de legendas em faixa separada é exclusiva de contas Premium.", "REQ-VID-TXT-004");
      }
      const blocks = params.blocks;
      if (!Array.isArray(blocks) || blocks.length === 0) throw new VideoRuleError(400, "invalid_params", "Adicione pelo menos um bloco de texto.");
      if (blocks.length > p.maxTextBlocks) {
        throw new VideoRuleError(403, "text_block_limit", `O seu perfil permite no máximo ${p.maxTextBlocks} blocos de texto por vídeo.`, "REQ-VID-TXT-007");
      }
      const norm = blocks.map((b, i) => {
        const text = typeof b.text === "string" ? b.text.trim() : "";
        if (!text || text.length > 500) throw new VideoRuleError(400, "invalid_params", `O bloco ${i + 1} tem texto vazio ou demasiado longo.`);
        const start = num(b.start, `blocks[${i}].start`, { min: 0 });
        const end = num(b.end, `blocks[${i}].end`, { min: 0 });
        if (!(start < end) || end > D + EPS) {
          throw new VideoRuleError(400, "invalid_interval", `O bloco ${i + 1} tem um intervalo inválido (início < fim, dentro da duração do vídeo).`, "REQ-VID-TXT-011");
        }
        const color = /^#[0-9a-fA-F]{6}$/.test(b.color || "") ? b.color : "#FFFFFF";
        return {
          text,
          start,
          end,
          x: num(b.x ?? 0.5, `blocks[${i}].x`, { min: 0, max: 1 }),
          y: num(b.y ?? 0.85, `blocks[${i}].y`, { min: 0, max: 1 }),
          size: num(b.size ?? 0.06, `blocks[${i}].size`, { min: 0.02, max: 0.3 }),
          color,
          font: FONTS.includes(b.font) ? b.font : "Noto Sans",
          bold: b.bold === true,
        };
      });
      return { op: { mode, blocks: norm }, expectedOutputDuration: D };
    }

    case "video_color": {
      requireTool(p, procedure);
      const preset = params.preset ?? "none";
      if (!COLOR_PRESETS.includes(preset)) throw new VideoRuleError(400, "invalid_params", "Filtro predefinido desconhecido.");
      const intensity = num(params.intensity ?? 100, "intensity", { min: 0, max: 100 });
      const m = params.manual || {};
      const manual = {
        brightness: num(m.brightness ?? 0, "brightness", { min: -1, max: 1 }),
        contrast: num(m.contrast ?? 1, "contrast", { min: 0, max: 2 }),
        saturation: num(m.saturation ?? 1, "saturation", { min: 0, max: 3 }),
        gamma: num(m.gamma ?? 1, "gamma", { min: 0.1, max: 3 }),
      };
      const lutId = params.lutId || null;
      if (lutId && !p.lut) {
        throw new VideoRuleError(403, "lut_premium", "A importação de LUTs 3D personalizados é exclusiva do perfil Premium.", "REQ-VID-COL-002");
      }
      if (lutId && !/^[a-f0-9-]{36}$/.test(lutId)) throw new VideoRuleError(400, "invalid_params", "Identificador de LUT inválido.");
      const manualChanged = manual.brightness !== 0 || manual.contrast !== 1 || manual.saturation !== 1 || manual.gamma !== 1;
      if ((preset === "none" || intensity === 0) && !manualChanged && !lutId) {
        throw new VideoRuleError(400, "invalid_params", "Escolha um filtro, um ajuste manual ou um LUT.");
      }
      return { op: { preset, intensity, manual, lutId }, expectedOutputDuration: D };
    }

    default:
      throw new VideoRuleError(400, "invalid_params", "Operação de vídeo desconhecida.");
  }
}

// ------------------------------------------------------------------ LUT 3D .cube (REQ-VID-COL-009)
const CUBE_SIZES = [17, 33, 65];

function validateCube(text) {
  let size = null;
  let values = 0;
  const lines = String(text).split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith("#")) continue;
    const parts = line.split(/\s+/);
    const head = parts[0].toUpperCase();
    if (head === "TITLE") continue;
    if (head === "LUT_1D_SIZE") throw new VideoRuleError(400, "invalid_lut", "LUT 1D não suportado: é necessário um LUT 3D.", "REQ-VID-COL-009");
    if (head === "LUT_3D_SIZE") {
      size = Number(parts[1]);
      if (!CUBE_SIZES.includes(size)) throw new VideoRuleError(400, "invalid_lut", `Grelha ${parts[1]}³ não suportada (use 17, 33 ou 65).`, "REQ-VID-COL-009");
      continue;
    }
    if (head === "DOMAIN_MIN" || head === "DOMAIN_MAX") {
      const expected = head === "DOMAIN_MIN" ? 0 : 1;
      if (parts.length !== 4 || parts.slice(1).some((v) => Number(v) !== expected)) {
        throw new VideoRuleError(400, "invalid_lut", `${head} não suportado.`, "REQ-VID-COL-009");
      }
      continue;
    }
    if (parts.length !== 3) throw new VideoRuleError(400, "invalid_lut", `Linha ${i + 1}: esperados três valores.`, "REQ-VID-COL-009");
    if (size === null) throw new VideoRuleError(400, "invalid_lut", "Cabeçalho LUT_3D_SIZE em falta.", "REQ-VID-COL-009");
    for (const v of parts) {
      const n = Number(v);
      if (!Number.isFinite(n)) throw new VideoRuleError(400, "invalid_lut", `Linha ${i + 1}: valor não numérico.`, "REQ-VID-COL-009");
      if (n < 0 || n > 1) throw new VideoRuleError(400, "invalid_lut", `Linha ${i + 1}: valores fora de [0,0; 1,0].`, "REQ-VID-COL-009");
    }
    values++;
  }
  if (size === null) throw new VideoRuleError(400, "invalid_lut", "Cabeçalho LUT_3D_SIZE em falta.", "REQ-VID-COL-009");
  if (values !== size ** 3) {
    throw new VideoRuleError(400, "invalid_lut", `Esperadas ${size ** 3} entradas para a grelha ${size}³, encontradas ${values}.`, "REQ-VID-COL-009");
  }
  return size;
}

// ------------------------------------------------------------------ legendas SRT / VTT (REQ-VID-TXT-002/009)
const TS = /^(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{3})$/;

function parseTimestamp(s, lineNo) {
  const m = TS.exec(s.trim());
  if (!m) throw new VideoRuleError(400, "invalid_subtitles", `Linha ${lineNo}: instante "${s.trim()}" inválido.`, "REQ-VID-TXT-009");
  const [, h = "0", mi, se, ms] = m;
  if (Number(mi) > 59 || Number(se) > 59) throw new VideoRuleError(400, "invalid_subtitles", `Linha ${lineNo}: instante inválido.`, "REQ-VID-TXT-009");
  return Number(h) * 3600 + Number(mi) * 60 + Number(se) + Number(ms) / 1000;
}

function decodeUtf8Strict(buffer) {
  try {
    const text = new TextDecoder("utf-8", { fatal: true }).decode(buffer);
    return text.replace(/^﻿/, "");
  } catch (_) {
    throw new VideoRuleError(400, "invalid_encoding", "Ficheiro de legendas corrompido ou formato não suportado (verifique a codificação UTF-8 e a sintaxe temporal).", "REQ-VID-TXT-009");
  }
}

function parseSubtitles(buffer) {
  const text = decodeUtf8Strict(buffer);
  const lines = text.split(/\r?\n/);
  const isVtt = /^WEBVTT/.test(lines[0] || "");
  const blocks = [];
  let i = isVtt ? 1 : 0;
  while (i < lines.length) {
    while (i < lines.length && lines[i].trim() === "") i++;
    if (i >= lines.length) break;
    // VTT: NOTE/STYLE/REGION são blocos sem legenda
    if (isVtt && /^(NOTE|STYLE|REGION)\b/.test(lines[i])) {
      while (i < lines.length && lines[i].trim() !== "") i++;
      continue;
    }
    let timingLine = i;
    if (!lines[i].includes("-->")) {
      if (!isVtt && !/^\d+$/.test(lines[i].trim())) {
        throw new VideoRuleError(400, "invalid_subtitles", `Linha ${i + 1}: numeração de bloco inválida.`, "REQ-VID-TXT-009");
      }
      timingLine = i + 1;
    }
    const timing = lines[timingLine] || "";
    if (!timing.includes("-->")) {
      throw new VideoRuleError(400, "invalid_subtitles", `Linha ${timingLine + 1}: falta a linha de tempo "início --> fim".`, "REQ-VID-TXT-009");
    }
    const [a, rest] = timing.split("-->");
    const b = rest.trim().split(/\s+/)[0]; // VTT pode ter definições depois do instante
    const start = parseTimestamp(a, timingLine + 1);
    const end = parseTimestamp(b, timingLine + 1);
    if (!(start < end)) {
      throw new VideoRuleError(400, "invalid_subtitles", `Linha ${timingLine + 1}: o fim tem de ser posterior ao início.`, "REQ-VID-TXT-009");
    }
    i = timingLine + 1;
    const content = [];
    while (i < lines.length && lines[i].trim() !== "") content.push(lines[i++]);
    const cleaned = content.join("\n").replace(/<[^>]+>/g, "").trim();
    if (cleaned) blocks.push({ text: cleaned, start, end });
  }
  if (blocks.length === 0) {
    throw new VideoRuleError(400, "invalid_subtitles", "O ficheiro não contém legendas.", "REQ-VID-TXT-009");
  }
  return blocks;
}

module.exports = {
  PROFILES,
  COLOR_PRESETS,
  FONTS,
  VideoRuleError,
  profileFor,
  publicProfile,
  validateSubmission,
  validateJob,
  validateCube,
  parseSubtitles,
};
