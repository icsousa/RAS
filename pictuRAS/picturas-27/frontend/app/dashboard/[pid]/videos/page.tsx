"use client";

// Página de vídeo de um projeto (Fase 1 — MVP de vídeo, UC-VID-001 a UC-VID-005).
import { use, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Download, Film, LoaderCircle, Trash2, Undo2, Upload, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { useToast } from "@/hooks/use-toast";
import { useSession } from "@/providers/session-provider";
import { useGetSocket } from "@/lib/queries/projects";
import { useUpdateSession } from "@/lib/mutations/session";
import OperationsCounter from "@/components/operations-counter";
import { VideoPreview, type PreviewState } from "@/components/video/video-preview";
import { ColorPanel, CropPanel, SpeedPanel, TextPanel, TrimPanel, type PanelProps } from "@/components/video/tool-panels";
import { Notice } from "@/components/video/fields";
import {
  ACTIVE_STATUSES,
  PROCEDURE_LABELS,
  STATUS_LABELS,
  WARNING_LABELS,
  cancelVideoJob,
  createVideoJob,
  deleteVideo,
  formatTime,
  getVideo,
  getVideoJob,
  getVideoLimits,
  listVideoJobs,
  listVideos,
  setActiveVersion,
  uploadVideo,
  videoErrorMessage,
  type Access,
  type VideoJob,
  type VideoProcedure,
} from "@/lib/videos";

const TABS: { id: VideoProcedure; label: string; Panel: (p: PanelProps) => React.ReactElement }[] = [
  { id: "video_trim", label: "Recorte", Panel: TrimPanel },
  { id: "video_crop", label: "Pan & Crop", Panel: CropPanel },
  { id: "video_speed", label: "Velocidade", Panel: SpeedPanel },
  { id: "video_text", label: "Legendas", Panel: TextPanel },
  { id: "video_color", label: "Cor", Panel: ColorPanel },
];

export default function ProjectVideosPage({ params }: { params: Promise<{ pid: string }> }) {
  const { pid } = use(params);
  const session = useSession();
  const router = useRouter();
  const search = useSearchParams();
  const qc = useQueryClient();
  const { toast } = useToast();
  const updateSession = useUpdateSession();
  const socket = useGetSocket(session.token);

  const ownerId = search.get("owner") ?? session.user._id;
  const shareId = search.get("share") ?? undefined;
  const access: Access = useMemo(
    () => ({ uid: session.user._id, pid, token: session.token, ownerId, shareId }),
    [session.user._id, pid, session.token, ownerId, shareId],
  );

  const limits = useQuery({ queryKey: ["videoLimits", access], queryFn: () => getVideoLimits(access) });
  const videos = useQuery({ queryKey: ["videos", access], queryFn: () => listVideos(access) });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selected = useQuery({
    queryKey: ["video", access, selectedId],
    queryFn: () => getVideo(access, selectedId as string),
    enabled: !!selectedId,
  });
  const jobs = useQuery({
    queryKey: ["videoJobs", access, selectedId],
    queryFn: () => listVideoJobs(access, selectedId as string),
    enabled: !!selectedId,
  });

  const [job, setJob] = useState<VideoJob | null>(null);
  const [tab, setTab] = useState<VideoProcedure>("video_trim");
  const [preview, setPreview] = useState<PreviewState>({ kind: "none" });
  const [uploading, setUploading] = useState<number | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!selectedId && videos.data && videos.data.length > 0) setSelectedId(videos.data[0]._id);
  }, [videos.data, selectedId]);

  // trabalho ativo do vídeo selecionado
  useEffect(() => {
    setJob(selected.data?.active_job ?? null);
  }, [selected.data?._id, selected.data?.active_job]);

  const refreshAll = useCallback(() => {
    qc.invalidateQueries({ queryKey: ["video", access, selectedId] });
    qc.invalidateQueries({ queryKey: ["videoJobs", access, selectedId] });
    qc.invalidateQueries({ queryKey: ["videos", access] });
  }, [qc, access, selectedId]);

  const jobRef = useRef<VideoJob | null>(null);
  useEffect(() => {
    jobRef.current = job;
  }, [job]);

  const onJobUpdate = useCallback(
    (j: VideoJob) => {
      if (j.video_id !== selectedId) {
        qc.invalidateQueries({ queryKey: ["videos", access] });
        return;
      }
      const prev = jobRef.current;
      if (prev && prev._id === j._id && !ACTIVE_STATUSES.includes(prev.status)) return; // já terminado
      jobRef.current = j;
      setJob(j);
      if (!ACTIVE_STATUSES.includes(j.status) && (!prev || prev._id !== j._id || ACTIVE_STATUSES.includes(prev.status))) {
        // transição para um estado final
        if (j.status === "completed") {
          toast({
            title: `${PROCEDURE_LABELS[j.procedure]} concluído`,
            description: j.warnings.length ? j.warnings.map((w) => WARNING_LABELS[w] ?? w).join(" ") : "Foi criada uma nova versão do vídeo.",
          });
        } else if (j.status === "failed") {
          toast({ title: "A operação falhou", description: j.error_message ?? "Erro no processamento.", variant: "destructive" });
        } else {
          toast({ title: "Operação cancelada", description: "O vídeo original mantém-se e a quota não foi debitada." });
        }
        refreshAll();
        updateSession.mutate({ userId: session.user._id, token: session.token }); // contador de operações (REQ-VID-QUOTA-003)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [selectedId, access, refreshAll],
  );

  // Atualizações em tempo real pelo WebSocket (REQ-VID-STATUS-001)
  useEffect(() => {
    const s = socket.data;
    if (!s) return;
    const handler = (payload: { projectId: string; job: VideoJob }) => {
      if (payload.projectId === pid) onJobUpdate(payload.job);
    };
    s.emit("join-project", pid);
    s.on("video-job", handler);
    return () => {
      s.off("video-job", handler);
      s.emit("leave-project", pid);
    };
  }, [socket.data, pid, onJobUpdate]);

  // Consulta periódica como alternativa ao WebSocket
  const jobId = job && ACTIVE_STATUSES.includes(job.status) ? job._id : null;
  useEffect(() => {
    if (!jobId) return;
    const t = setInterval(() => {
      getVideoJob(access, jobId).then(onJobUpdate).catch(() => {});
    }, 3000);
    return () => clearInterval(t);
  }, [jobId, access, onJobUpdate]);

  const busy = !!jobId;
  const version = selected.data?.active ?? null;
  const profile = limits.data;

  const apply = async (procedure: VideoProcedure, params: Record<string, unknown>) => {
    if (!selectedId) return;
    try {
      const j = await createVideoJob(access, selectedId, procedure, params);
      jobRef.current = j;
      setJob(j);
      updateSession.mutate({ userId: session.user._id, token: session.token });
    } catch (e) {
      toast({ title: "Não foi possível iniciar a operação", description: videoErrorMessage(e), variant: "destructive" });
    }
  };

  const onUpload = async (file: File) => {
    if (profile && file.size > 500 * 1024 * 1024) {
      toast({ title: "Ficheiro demasiado grande", description: "O máximo é 500 MB.", variant: "destructive" });
      return;
    }
    setUploading(0);
    try {
      const v = await uploadVideo(access, file, setUploading);
      await qc.invalidateQueries({ queryKey: ["videos", access] });
      setSelectedId(v._id);
      toast({ title: "Vídeo carregado", description: `${v.name} (${formatTime(v.active?.duration ?? 0)})` });
    } catch (e) {
      toast({ title: "Vídeo rejeitado", description: videoErrorMessage(e), variant: "destructive" });
    } finally {
      setUploading(null);
    }
  };

  const changeVersion = async (to: string) => {
    if (!selectedId) return;
    try {
      await setActiveVersion(access, selectedId, to);
      refreshAll();
    } catch (e) {
      toast({ title: "Não foi possível mudar de versão", description: videoErrorMessage(e), variant: "destructive" });
    }
  };

  const qs = shareId ? `?owner=${ownerId}&share=${shareId}` : "";
  const ActivePanel = TABS.find((t) => t.id === tab)?.Panel;

  return (
    <div className="flex flex-col h-screen overflow-hidden">
      <header className="flex items-center justify-between gap-2 border-b px-4 py-3">
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => router.push(`/dashboard/${pid}${qs}`)}>
            <ArrowLeft /> Imagens
          </Button>
          <h1 className="text-lg font-semibold flex items-center gap-2">
            <Film className="size-5" /> Vídeos do projeto
          </h1>
        </div>
        <div className="flex items-center gap-4">
          <OperationsCounter />
          {profile && (
            <span className="text-xs text-muted-foreground hidden md:inline">
              Perfil: até {profile.maxDurationSec} s, saída até {profile.maxShortSide}p
            </span>
          )}
          <Button size="sm" onClick={() => fileRef.current?.click()} disabled={uploading !== null}>
            {uploading !== null ? <LoaderCircle className="animate-spin" /> : <Upload />} Carregar vídeo
          </Button>
          <input
            ref={fileRef}
            type="file"
            accept="video/mp4,video/quicktime,.mp4,.mov"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) onUpload(f);
              e.target.value = "";
            }}
          />
        </div>
      </header>

      {uploading !== null && (
        <div className="px-4 py-2 border-b">
          <Progress value={uploading} />
          <span className="text-xs text-muted-foreground">A carregar… {uploading}% (o vídeo é validado no fim)</span>
        </div>
      )}

      <div className="flex flex-1 overflow-hidden">
        {/* Lista de vídeos */}
        <aside className="w-56 border-r overflow-auto p-2 hidden md:block">
          {videos.isLoading && <LoaderCircle className="animate-spin m-4" />}
          {videos.data?.length === 0 && (
            <p className="text-sm text-muted-foreground p-2">Ainda não há vídeos. Carregue um MP4 ou MOV (H.264/AAC).</p>
          )}
          <ul className="flex flex-col gap-1">
            {videos.data?.map((v) => (
              <li key={v._id}>
                <button
                  className={`w-full rounded-md px-2 py-2 text-left text-sm hover:bg-accent ${v._id === selectedId ? "bg-accent font-medium" : ""}`}
                  onClick={() => {
                    setSelectedId(v._id);
                    setPreview({ kind: "none" });
                  }}
                >
                  <div className="truncate">{v.name}</div>
                  <div className="text-xs text-muted-foreground">
                    {formatTime(v.active?.duration ?? 0)} · {v.active?.width}×{v.active?.height}
                    {v.active_job ? ` · ${STATUS_LABELS[v.active_job.status]}` : ""}
                  </div>
                </button>
              </li>
            ))}
          </ul>
        </aside>

        {/* Editor */}
        <main className="flex-1 overflow-auto p-4 flex flex-col gap-4">
          {!version && selectedId && <LoaderCircle className="animate-spin" />}
          {version && (
            <>
              <VideoPreview version={version} preview={preview} videoRef={videoRef} />

              {job && (
                <div className="rounded-md border p-3 flex flex-col gap-2">
                  <div className="flex items-center justify-between text-sm">
                    <span>
                      {PROCEDURE_LABELS[job.procedure]} — <b>{STATUS_LABELS[job.status]}</b>
                      {job.status === "processing" ? ` (${job.progress}%)` : ""}
                    </span>
                    {ACTIVE_STATUSES.includes(job.status) && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => cancelVideoJob(access, job._id).then(onJobUpdate).catch((e) => toast({ title: "Erro", description: videoErrorMessage(e), variant: "destructive" }))}
                      >
                        <X /> Cancelar
                      </Button>
                    )}
                  </div>
                  {ACTIVE_STATUSES.includes(job.status) && <Progress value={job.status === "queued" ? 0 : job.progress} />}
                  {job.status === "failed" && <Notice tone="error">{job.error_message}</Notice>}
                  {job.status === "completed" && job.warnings.length > 0 && (
                    <Notice tone="warn">{job.warnings.map((w) => WARNING_LABELS[w] ?? w).join(" ")}</Notice>
                  )}
                </div>
              )}

              <div className="flex flex-col lg:flex-row gap-4">
                <section className="flex-1 min-w-0">
                  <div className="flex flex-wrap gap-1 border-b pb-2 mb-3">
                    {TABS.map((t) => {
                      const allowed = profile?.tools.includes(t.id) ?? true;
                      return (
                        <Button
                          key={t.id}
                          size="sm"
                          variant={tab === t.id ? "default" : "ghost"}
                          disabled={!allowed}
                          title={allowed ? undefined : "Disponível para utilizadores registados"}
                          onClick={() => {
                            setTab(t.id);
                            setPreview({ kind: "none" });
                          }}
                        >
                          {t.label}
                        </Button>
                      );
                    })}
                  </div>
                  {profile && profile.tools.length < TABS.length && (
                    <div className="mb-3">
                      <Notice>Pan & Crop e Legendas estão disponíveis para utilizadores registados.</Notice>
                    </div>
                  )}
                  {profile && ActivePanel && (
                    <ActivePanel
                      key={`${tab}-${version._id}`}
                      version={version}
                      profile={profile}
                      videoRef={videoRef}
                      setPreview={setPreview}
                      apply={apply}
                      busy={busy}
                      access={access}
                    />
                  )}
                </section>

                {/* Versões e histórico (REQ-VID-RESULT-001/002/003) */}
                <section className="lg:w-72 flex flex-col gap-3">
                  <div className="flex flex-col gap-2">
                    <h2 className="text-sm font-semibold">Versões</h2>
                    <div className="flex gap-2">
                      <Button size="sm" variant="outline" disabled={busy || !version.parent_id} onClick={() => changeVersion("previous")}>
                        <Undo2 /> Reverter
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={busy || (selected.data?.versions?.[0]?._id ?? version._id) === version._id}
                        onClick={() => changeVersion("original")}
                      >
                        Reset
                      </Button>
                      {version.url && (
                        <a href={version.url} download className="inline-flex">
                          <Button size="sm" variant="outline" title="Descarregar MP4">
                            <Download />
                          </Button>
                        </a>
                      )}
                    </div>
                    {!version.parent_id && <span className="text-xs text-muted-foreground">Não existem versões anteriores.</span>}
                    <ul className="flex flex-col gap-1 max-h-48 overflow-auto">
                      {selected.data?.versions?.map((v, i) => (
                        <li key={v._id}>
                          <button
                            disabled={busy}
                            className={`w-full rounded border px-2 py-1 text-left text-xs ${v._id === version._id ? "border-primary bg-accent" : ""}`}
                            onClick={() => changeVersion(v._id)}
                          >
                            v{i + 1} · {v.procedure ? PROCEDURE_LABELS[v.procedure] : "Original"} · {formatTime(v.duration)} · {v.width}×{v.height}
                            {!v.has_audio ? " · sem som" : ""}
                            {v.subtitle_streams ? " · legendas" : ""}
                          </button>
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div className="flex flex-col gap-1">
                    <h2 className="text-sm font-semibold">Histórico</h2>
                    <ul className="flex flex-col gap-1 max-h-48 overflow-auto text-xs">
                      {jobs.data?.map((j) => (
                        <li key={j._id} className="rounded border px-2 py-1">
                          {PROCEDURE_LABELS[j.procedure]} · {STATUS_LABELS[j.status]}
                          {j.created_at ? ` · ${new Date(j.created_at).toLocaleString("pt-PT")}` : ""}
                          {j.status === "failed" && j.error_message ? <div className="text-red-600">{j.error_message}</div> : null}
                        </li>
                      ))}
                      {jobs.data?.length === 0 && <li className="text-muted-foreground">Sem operações.</li>}
                    </ul>
                  </div>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="text-red-600 self-start"
                    disabled={busy}
                    onClick={async () => {
                      if (!selectedId || !confirm("Apagar este vídeo e todas as versões?")) return;
                      try {
                        await deleteVideo(access, selectedId);
                        setSelectedId(null);
                        qc.invalidateQueries({ queryKey: ["videos", access] });
                      } catch (e) {
                        toast({ title: "Erro", description: videoErrorMessage(e), variant: "destructive" });
                      }
                    }}
                  >
                    <Trash2 /> Apagar vídeo
                  </Button>
                </section>
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
