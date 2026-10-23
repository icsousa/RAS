"use client";

// Reprodutor com pré-visualização no cliente (DQ-002): nada aqui cria trabalhos no servidor.
//  - Recorte: reprodução limitada ao segmento (REQ-VID-TRIM-011)
//  - Pan & Crop: moldura editável e animação interpolada (REQ-VID-CROP-001/002/003/004)
//  - Velocidade: playbackRate (REQ-VID-SPD-011)
//  - Legendas: texto sobreposto em tempo real (REQ-VID-TXT-001)
//  - Cor: filtro CSS acelerado por GPU (REQ-VID-COL-001/006)
import { useCallback, useEffect, useRef, useState } from "react";
import type { Keyframe, TextBlock, VideoVersion } from "@/lib/videos";

export type PreviewState =
  | { kind: "none" }
  | { kind: "trim"; tin: number; tout: number; playSegment: number }
  | { kind: "speed"; rate: number; pitch: boolean }
  | { kind: "color"; filter: string }
  | { kind: "text"; blocks: TextBlock[] }
  | {
      kind: "crop";
      box: { x: number; y: number; w: number; h: number };
      aspect: number;
      keyframes: Keyframe[];
      animate: boolean;
      onBoxChange: (b: { x: number; y: number; w: number; h: number }) => void;
    };

export function interpolate(kfs: Keyframe[], t: number) {
  const s = [...kfs].sort((a, b) => a.t - b.t);
  if (s.length === 0) return null;
  if (t <= s[0].t) return s[0];
  for (let i = 0; i < s.length - 1; i++) {
    const a = s[i];
    const b = s[i + 1];
    if (t >= a.t && t <= b.t) {
      const r = b.t === a.t ? 0 : (t - a.t) / (b.t - a.t);
      return { t, x: a.x + (b.x - a.x) * r, y: a.y + (b.y - a.y) * r, w: a.w + (b.w - a.w) * r, h: a.h + (b.h - a.h) * r };
    }
  }
  return s[s.length - 1];
}

export function useVideoTime(videoRef: React.RefObject<HTMLVideoElement | null>) {
  const [time, setTime] = useState(0);
  useEffect(() => {
    let raf = 0;
    const tick = () => {
      const v = videoRef.current;
      if (v) setTime(v.currentTime);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [videoRef]);
  return time;
}

export function VideoPreview({
  version,
  preview,
  videoRef,
}: {
  version: VideoVersion;
  preview: PreviewState;
  videoRef: React.RefObject<HTMLVideoElement | null>;
}) {
  const time = useVideoTime(videoRef);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [height, setHeight] = useState(0);
  const W = version.width;
  const H = version.height;

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const obs = new ResizeObserver(() => setHeight(el.clientHeight));
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  // Velocidade
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    if (preview.kind === "speed") {
      v.playbackRate = Math.min(16, Math.max(0.0625, preview.rate));
      (v as HTMLVideoElement & { preservesPitch?: boolean }).preservesPitch = preview.pitch;
    } else {
      v.playbackRate = 1;
      (v as HTMLVideoElement & { preservesPitch?: boolean }).preservesPitch = true;
    }
  }, [preview, videoRef]);

  // Recorte: reproduzir só o segmento selecionado
  const trimTin = preview.kind === "trim" ? preview.tin : null;
  const trimTout = preview.kind === "trim" ? preview.tout : null;
  const playSegment = preview.kind === "trim" ? preview.playSegment : 0;
  useEffect(() => {
    const v = videoRef.current;
    if (!v || trimTin === null || !playSegment) return;
    v.currentTime = trimTin;
    v.play().catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playSegment]);
  useEffect(() => {
    const v = videoRef.current;
    if (v && trimTout !== null && playSegment && !v.paused && time >= trimTout) v.pause();
  }, [time, trimTout, playSegment, videoRef]);

  // Pan & Crop: arrastar e redimensionar a moldura (em píxeis da origem)
  const drag = useRef<{ mode: "move" | "resize"; sx: number; sy: number; box: { x: number; y: number; w: number; h: number } } | null>(null);
  const toSource = useCallback(
    (dx: number, dy: number) => {
      const el = containerRef.current;
      if (!el) return { dx: 0, dy: 0 };
      return { dx: (dx / el.clientWidth) * W, dy: (dy / el.clientHeight) * H };
    },
    [W, H],
  );

  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag.current || preview.kind !== "crop") return;
    const { dx, dy } = toSource(e.clientX - drag.current.sx, e.clientY - drag.current.sy);
    const b = drag.current.box;
    const minW = Math.max(Math.min(320, W), Math.min(240, H) * preview.aspect);
    if (drag.current.mode === "move") {
      preview.onBoxChange({
        ...b,
        x: Math.min(Math.max(0, b.x + dx), W - b.w),
        y: Math.min(Math.max(0, b.y + dy), H - b.h),
      });
    } else {
      // rácio fixo (REQ-VID-CROP-003) e dimensão mínima (REQ-VID-CROP-004)
      let w = Math.max(minW, b.w + dx);
      w = Math.min(w, W - b.x, (H - b.y) * preview.aspect);
      preview.onBoxChange({ ...b, w, h: w / preview.aspect });
    }
  };

  const filter = preview.kind === "color" ? preview.filter : undefined;
  const animated =
    preview.kind === "crop" && preview.animate && preview.keyframes.length > 0 ? interpolate(preview.keyframes, time) : null;

  const textBlocks = preview.kind === "text" ? preview.blocks.filter((b) => time >= b.start && time <= b.end) : [];

  return (
    <div className="flex justify-center w-full">
      <div
        ref={containerRef}
        className="relative overflow-hidden rounded-md bg-black max-h-[55vh]"
        style={{
          aspectRatio: animated ? `${animated.w} / ${animated.h}` : `${W} / ${H}`,
          width: "100%",
          maxWidth: `calc(55vh * ${animated ? animated.w / animated.h : W / H})`,
        }}
        onPointerMove={onPointerMove}
        onPointerUp={() => (drag.current = null)}
        onPointerLeave={() => (drag.current = null)}
      >
        <video
          ref={videoRef}
          key={version._id}
          src={version.url ?? undefined}
          controls={!animated}
          playsInline
          className="absolute"
          style={
            animated
              ? {
                  width: `${(W / animated.w) * 100}%`,
                  height: `${(H / animated.h) * 100}%`,
                  left: `${-(animated.x / animated.w) * 100}%`,
                  top: `${-(animated.y / animated.h) * 100}%`,
                  maxWidth: "none",
                  filter,
                }
              : { inset: 0, width: "100%", height: "100%", filter }
          }
        />

        {preview.kind === "crop" && !preview.animate && (
          <div
            className="absolute border-2 border-amber-400 bg-amber-400/10 cursor-move touch-none"
            style={{
              left: `${(preview.box.x / W) * 100}%`,
              top: `${(preview.box.y / H) * 100}%`,
              width: `${(preview.box.w / W) * 100}%`,
              height: `${(preview.box.h / H) * 100}%`,
              boxShadow: "0 0 0 9999px rgba(0,0,0,0.45)",
            }}
            onPointerDown={(e) => {
              (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
              drag.current = { mode: "move", sx: e.clientX, sy: e.clientY, box: preview.box };
            }}
          >
            <div
              className="absolute -right-2 -bottom-2 size-4 rounded-sm bg-amber-400 cursor-nwse-resize"
              onPointerDown={(e) => {
                e.stopPropagation();
                (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
                drag.current = { mode: "resize", sx: e.clientX, sy: e.clientY, box: preview.box };
              }}
            />
            <span className="absolute left-1 top-1 text-[10px] font-mono text-amber-200">
              {Math.round(preview.box.w)}×{Math.round(preview.box.h)}
            </span>
          </div>
        )}

        {textBlocks.map((b, i) => (
          <div
            key={i}
            className="absolute pointer-events-none whitespace-pre-wrap text-center"
            style={{
              left: `${b.x * 100}%`,
              top: `${b.y * 100}%`,
              transform: "translate(-50%, -50%)",
              color: b.color,
              fontFamily: `"${b.font}", sans-serif`,
              fontWeight: b.bold ? 700 : 400,
              fontSize: `${Math.max(8, b.size * height)}px`,
              lineHeight: 1.15,
              textShadow: "0 0 3px #000, 0 0 2px #000",
            }}
          >
            {b.text}
          </div>
        ))}
      </div>
    </div>
  );
}
