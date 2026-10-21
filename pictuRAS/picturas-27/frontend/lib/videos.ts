// Cliente da API de vídeo (Fase 1 — MVP de vídeo).
import { api } from "./axios";
import axios from "axios";

export type VideoProcedure =
  | "video_trim"
  | "video_crop"
  | "video_speed"
  | "video_text"
  | "video_color";

export type JobStatus = "queued" | "processing" | "completed" | "failed" | "cancelled";

export interface VideoProfile {
  type: "anonymous" | "free" | "premium";
  maxDurationSec: number;
  maxShortSide: number;
  speed: [number, number];
  tools: VideoProcedure[];
  maxKeyframes: number | null; // null = sem limite
  maxTextBlocks: number | null;
  softSub: boolean;
  lut: boolean;
  countsQuota: boolean;
}

export interface VideoVersion {
  _id: string;
  parent_id: string | null;
  url: string | null;
  duration: number;
  width: number;
  height: number;
  fps: number;
  has_audio: boolean;
  subtitle_streams: number;
  keyframes: number[];
  keyframe_count: number;
  procedure: VideoProcedure | null;
  params: Record<string, unknown> | null;
  created_at: string;
  size: number;
}

export interface VideoJob {
  _id: string;
  video_id: string;
  procedure: VideoProcedure;
  params: Record<string, unknown>;
  status: JobStatus;
  progress: number;
  error_code: string | null;
  error_message: string | null;
  warnings: string[];
  meta: Record<string, unknown>;
  result_version: string | null;
  created_at: string | null;
  finished_at: string | null;
}

export interface Video {
  _id: string;
  name: string;
  project_id: string;
  user_id: string;
  active_version: string | null;
  active: VideoVersion | null;
  versions?: VideoVersion[];
  active_job: VideoJob | null;
  created_at: string;
}

export interface TextBlock {
  text: string;
  start: number;
  end: number;
  x: number;
  y: number;
  size: number;
  color: string;
  font: string;
  bold: boolean;
}

export interface Keyframe {
  t: number;
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Access {
  uid: string;
  pid: string;
  token: string;
  ownerId?: string;
  shareId?: string;
}

function base({ uid, pid, ownerId, shareId }: Access) {
  const owner = shareId ? ownerId ?? uid : uid;
  return `/projects/${owner}/${pid}/videos`;
}

function config(a: Access) {
  return {
    headers: { Authorization: `Bearer ${a.token}` },
    params: a.shareId ? { owner: a.ownerId, share: a.shareId } : undefined,
  };
}

export const ACTIVE_STATUSES: JobStatus[] = ["queued", "processing"];

export async function getVideoLimits(a: Access) {
  return (await api.get<VideoProfile>(`${base(a)}/limits`, config(a))).data;
}

export async function listVideos(a: Access) {
  return (await api.get<Video[]>(base(a), config(a))).data;
}

export async function getVideo(a: Access, videoId: string) {
  return (await api.get<Video>(`${base(a)}/${videoId}`, config(a))).data;
}

export async function uploadVideo(a: Access, file: File, onProgress?: (pct: number) => void) {
  const data = new FormData();
  data.append("video", file);
  const resp = await api.post<Video>(base(a), data, {
    ...config(a),
    onUploadProgress: (e) => {
      if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100));
    },
  });
  return resp.data;
}

export async function deleteVideo(a: Access, videoId: string) {
  await api.delete(`${base(a)}/${videoId}`, config(a));
}

export async function createVideoJob(
  a: Access,
  videoId: string,
  procedure: VideoProcedure,
  params: Record<string, unknown>,
) {
  return (await api.post<VideoJob>(`${base(a)}/${videoId}/jobs`, { procedure, params }, config(a))).data;
}

export async function listVideoJobs(a: Access, videoId: string) {
  return (await api.get<VideoJob[]>(`${base(a)}/${videoId}/jobs`, config(a))).data;
}

export async function getVideoJob(a: Access, jobId: string) {
  return (await api.get<VideoJob>(`${base(a)}/jobs/${jobId}`, config(a))).data;
}

export async function cancelVideoJob(a: Access, jobId: string) {
  return (await api.post<VideoJob>(`${base(a)}/jobs/${jobId}/cancel`, {}, config(a))).data;
}

// to: "previous" (Reverter), "original" (Reset) ou o id de uma versão
export async function setActiveVersion(a: Access, videoId: string, to: string) {
  return (await api.post<Video>(`${base(a)}/${videoId}/active`, { to }, config(a))).data;
}

export async function uploadLut(a: Access, file: File) {
  const data = new FormData();
  data.append("lut", file);
  return (await api.post<{ lutId: string; size: number; name: string }>(`${base(a)}/luts`, data, config(a))).data;
}

export async function parseSubtitleFile(a: Access, file: File) {
  const data = new FormData();
  data.append("subtitles", file);
  return (await api.post<{ blocks: { text: string; start: number; end: number }[] }>(
    `${base(a)}/subtitles/parse`,
    data,
    config(a),
  )).data.blocks;
}

export function videoErrorMessage(err: unknown, fallback = "Ocorreu um erro inesperado.") {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as { message?: string } | string | undefined;
    if (typeof data === "string") return data;
    if (data?.message) return data.message;
    if (err.response?.status === 413) return "O ficheiro é demasiado grande.";
  }
  return fallback;
}

export const PROCEDURE_LABELS: Record<VideoProcedure, string> = {
  video_trim: "Recorte temporal",
  video_crop: "Pan & Crop",
  video_speed: "Velocidade",
  video_text: "Legendas e texto",
  video_color: "Filtros de cor",
};

export const STATUS_LABELS: Record<JobStatus, string> = {
  queued: "Em fila",
  processing: "A processar",
  completed: "Concluído",
  failed: "Falhado",
  cancelled: "Cancelado",
};

export const WARNING_LABELS: Record<string, string> = {
  fast_mode_unavailable_resolution:
    "O corte rápido não é possível porque o vídeo excede a resolução do seu perfil; foi usado o corte preciso.",
  pitch_not_guaranteed: "Fora de 0.5x–2x a correção de tom pode produzir artefactos sonoros.",
  audio_removed_incompatible:
    "O vídeo foi processado sem som por incompatibilidade da faixa de áudio com a velocidade pedida.",
  font_fallback_used: "Alguns caracteres foram desenhados com uma fonte alternativa.",
};

export function formatTime(t: number) {
  if (!Number.isFinite(t)) return "0:00.000";
  const m = Math.floor(t / 60);
  const s = t - m * 60;
  return `${m}:${s.toFixed(3).padStart(6, "0")}`;
}
