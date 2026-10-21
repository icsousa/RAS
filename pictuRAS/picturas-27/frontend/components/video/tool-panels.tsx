"use client";

// Painéis das cinco ferramentas de vídeo. Cada painel valida no cliente o que pode
// (a validação definitiva é feita no serviço projects) e mostra a pré-visualização.
import { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Field, NumberInput, Notice, Range, Toggle } from "./fields";
import type { PreviewState } from "./video-preview";
import {
  formatTime,
  type Access,
  type Keyframe,
  type TextBlock,
  type VideoProcedure,
  type VideoProfile,
  type VideoVersion,
  parseSubtitleFile,
  uploadLut,
  videoErrorMessage,
} from "@/lib/videos";

export interface PanelProps {
  version: VideoVersion;
  profile: VideoProfile;
  videoRef: React.RefObject<HTMLVideoElement | null>;
  setPreview: (p: PreviewState) => void;
  apply: (procedure: VideoProcedure, params: Record<string, unknown>) => void;
  busy: boolean;
  access: Access;
}

const now = (ref: PanelProps["videoRef"]) => Math.round((ref.current?.currentTime ?? 0) * 1000) / 1000;

function ApplyBar({ disabled, busy, onClick, reason }: { disabled: boolean; busy: boolean; onClick: () => void; reason?: string | null }) {
  return (
    <div className="flex flex-col gap-2 pt-2">
      {reason && <Notice tone="error">{reason}</Notice>}
      <Button disabled={disabled || busy} onClick={onClick}>
        {busy ? "Há uma operação em curso…" : "Aplicar"}
      </Button>
    </div>
  );
}

// ------------------------------------------------------------------ UC-VID-001 Recorte temporal
export function TrimPanel({ version, videoRef, setPreview, apply, busy }: PanelProps) {
  const D = version.duration;
  const [tin, setTin] = useState(0);
  const [tout, setTout] = useState(Math.round(D * 1000) / 1000);
  const [fast, setFast] = useState(false);
  const [play, setPlay] = useState(0);

  const invalid = tin >= tout || tout - tin < 0.5 || tin < 0 || tout > D + 0.001;
  const reason = invalid ? "O instante de término deve ser superior ao de início e o excerto ter pelo menos 0,5 s (REQ-VID-TRIM-004)." : null;

  // Corte rápido: marcadores alinhados aos keyframes adjacentes (REQ-VID-TRIM-003)
  const aligned = useMemo(() => {
    const k = version.keyframes?.length ? version.keyframes : [0];
    const s = Math.max(...k.filter((x) => x <= tin + 1e-6), k[0]);
    const after = k.filter((x) => x >= tout - 1e-6);
    return { s, e: after.length ? Math.min(...after) : D };
  }, [version.keyframes, tin, tout, D]);

  useEffect(() => {
    setPreview({ kind: "trim", tin: fast ? aligned.s : tin, tout: fast ? aligned.e : tout, playSegment: play });
  }, [tin, tout, fast, aligned, play, setPreview]);

  useEffect(() => {
    const v = videoRef.current;
    if (v && !invalid) v.currentTime = tin;
    // atualizar o fotograma mostrado ao mover o marcador de início (REQ-VID-TRIM-002)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tin]);
  useEffect(() => {
    const v = videoRef.current;
    if (v && !invalid) v.currentTime = Math.max(0, tout - 0.001);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tout]);

  return (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Início (t_in), s">
          <NumberInput value={tin} onChange={setTin} min={0} max={D} invalid={invalid} />
          <Range value={tin} onChange={setTin} min={0} max={D} step={0.001} />
          <Button size="sm" variant="outline" onClick={() => setTin(now(videoRef))}>Usar instante atual</Button>
        </Field>
        <Field label="Fim (t_out), s">
          <NumberInput value={tout} onChange={setTout} min={0} max={D} invalid={invalid} />
          <Range value={tout} onChange={setTout} min={0} max={D} step={0.001} />
          <Button size="sm" variant="outline" onClick={() => setTout(now(videoRef))}>Usar instante atual</Button>
        </Field>
      </div>
      <div className="text-sm">
        Duração do excerto: <span className="font-semibold tabular-nums">{formatTime(Math.max(0, (fast ? aligned.e - aligned.s : tout - tin)))}</span>
      </div>
      <Toggle checked={fast} onChange={setFast} label="Corte rápido (sem recodificação, alinhado a keyframes)" />
      {fast && (
        <Notice>
          O corte fica entre os keyframes {formatTime(aligned.s)} e {formatTime(aligned.e)}. Sem esta opção o corte é preciso ao fotograma.
        </Notice>
      )}
      <Button variant="secondary" disabled={invalid} onClick={() => setPlay((n) => n + 1)}>Pré-visualizar segmento</Button>
      <ApplyBar disabled={invalid} busy={busy} reason={reason} onClick={() => apply("video_trim", { start: tin, end: tout, mode: fast ? "fast" : "precise" })} />
    </div>
  );
}

// ------------------------------------------------------------------ UC-VID-002 Pan & Crop
const ASPECTS: { label: string; value: number | "source" }[] = [
  { label: "Original", value: "source" },
  { label: "16:9", value: 16 / 9 },
  { label: "9:16", value: 9 / 16 },
  { label: "1:1", value: 1 },
  { label: "4:5", value: 4 / 5 },
];

export function CropPanel({ version, profile, videoRef, setPreview, apply, busy }: PanelProps) {
  const W = version.width;
  const H = version.height;
  const [aspectKey, setAspectKey] = useState<string>("Original");
  const aspect = (() => {
    const a = ASPECTS.find((x) => x.label === aspectKey)?.value ?? "source";
    return a === "source" ? W / H : a;
  })();
  const fitBox = (a: number) => {
    let w = W * 0.6;
    let h = w / a;
    if (h > H * 0.9) {
      h = H * 0.9;
      w = h * a;
    }
    const minW = Math.max(Math.min(320, W), Math.min(240, H) * a);
    w = Math.max(w, Math.min(minW, W));
    h = w / a;
    return { x: (W - w) / 2, y: (H - h) / 2, w, h };
  };
  const [box, setBox] = useState(() => fitBox(W / H));
  const [keyframes, setKeyframes] = useState<Keyframe[]>([]);
  const [animate, setAnimate] = useState(false);
  const limit = profile.maxKeyframes;

  useEffect(() => {
    // mudar o rácio obriga a recomeçar os keyframes (todos têm o mesmo rácio)
    setBox(fitBox(aspect));
    setKeyframes([]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aspectKey]);

  useEffect(() => {
    setPreview({ kind: "crop", box, aspect, keyframes, animate, onBoxChange: setBox });
  }, [box, aspect, keyframes, animate, setPreview]);

  const sorted = [...keyframes].sort((a, b) => a.t - b.t);
  const atLimit = limit !== null && keyframes.length >= limit;
  const tooSmall = box.w < Math.min(320, W) - 0.5 || box.h < Math.min(240, H) - 0.5;

  const addOrUpdate = () => {
    const t = now(videoRef);
    const existing = keyframes.findIndex((k) => Math.abs(k.t - t) < 0.001);
    const kf = { t, ...box };
    if (existing >= 0) setKeyframes(keyframes.map((k, i) => (i === existing ? kf : k)));
    else if (!atLimit) setKeyframes([...keyframes, kf]);
  };

  return (
    <div className="flex flex-col gap-3">
      <Field label="Rácio de aspeto">
        <div className="flex flex-wrap gap-1">
          {ASPECTS.map((a) => (
            <Button key={a.label} size="sm" variant={aspectKey === a.label ? "default" : "outline"} onClick={() => setAspectKey(a.label)}>
              {a.label}
            </Button>
          ))}
        </div>
      </Field>
      <Notice>
        Posicione o cursor do vídeo, arraste a moldura (canto inferior direito para redimensionar) e adicione um keyframe. Entre keyframes a
        moldura é interpolada linearmente. Mínimo 320×240 píxeis.
      </Notice>
      <div className="flex gap-2 flex-wrap">
        <Button size="sm" onClick={addOrUpdate} disabled={tooSmall || (atLimit && !keyframes.some((k) => Math.abs(k.t - now(videoRef)) < 0.001))}>
          Adicionar keyframe no instante atual
        </Button>
        <Button size="sm" variant="secondary" disabled={keyframes.length === 0} onClick={() => setAnimate(!animate)}>
          {animate ? "Editar moldura" : "Pré-visualizar animação"}
        </Button>
      </div>
      {atLimit && limit !== null && (
        <Notice tone="warn">O seu perfil permite no máximo {limit} keyframes por vídeo. Mude para Premium para keyframes ilimitados.</Notice>
      )}
      <div className="text-xs text-muted-foreground">
        Keyframes: {keyframes.length}
        {limit !== null ? ` / ${limit}` : ""}
      </div>
      <ul className="flex flex-col gap-1">
        {sorted.map((k) => (
          <li key={k.t} className="flex items-center justify-between rounded border px-2 py-1 text-xs">
            <button
              className="font-mono underline-offset-2 hover:underline"
              onClick={() => {
                if (videoRef.current) videoRef.current.currentTime = k.t;
                setBox({ x: k.x, y: k.y, w: k.w, h: k.h });
                setAnimate(false);
              }}
            >
              {formatTime(k.t)} — [{Math.round(k.x)}, {Math.round(k.y)}, {Math.round(k.w)}×{Math.round(k.h)}]
            </button>
            <button className="text-red-600" onClick={() => setKeyframes(keyframes.filter((x) => x !== k))}>
              Remover
            </button>
          </li>
        ))}
      </ul>
      <ApplyBar
        disabled={keyframes.length === 0}
        busy={busy}
        reason={keyframes.length === 0 ? "Adicione pelo menos um keyframe." : null}
        onClick={() => apply("video_crop", { keyframes: sorted })}
      />
    </div>
  );
}

// ------------------------------------------------------------------ UC-VID-003 Velocidade
const SPEED_SHORTCUTS = [0.25, 0.5, 1, 2, 4];

export function SpeedPanel({ version, profile, setPreview, apply, busy, videoRef }: PanelProps) {
  const [lo, hi] = profile.speed;
  const D = version.duration;
  const [factor, setFactor] = useState(1);
  const [pitch, setPitch] = useState(true);
  const [removeAudio, setRemoveAudio] = useState(false);
  const [useSegment, setUseSegment] = useState(false);
  const [segStart, setSegStart] = useState(0);
  const [segEnd, setSegEnd] = useState(Math.min(D, 5));

  const clamp = (f: number) => Math.min(hi, Math.max(lo, f)); // REQ-VID-SPD-002
  const segLen = useSegment ? Math.max(0, Math.min(segEnd, D) - segStart) : D;
  const finalDuration = D - segLen + segLen / factor;
  const tooLong = finalDuration > profile.maxDurationSec + 0.5; // REQ-VID-SPD-009
  const badSegment = useSegment && segEnd - segStart < 0.1;

  useEffect(() => setPreview({ kind: "speed", rate: factor, pitch }), [factor, pitch, setPreview]);

  return (
    <div className="flex flex-col gap-3">
      <Field label={`Fator de velocidade (o seu perfil: ${lo}x – ${hi}x)`}>
        <div className="flex flex-wrap gap-1">
          {SPEED_SHORTCUTS.map((s) => (
            <Button key={s} size="sm" variant={factor === s ? "default" : "outline"} disabled={s < lo || s > hi} onClick={() => setFactor(s)}>
              {s}x
            </Button>
          ))}
        </div>
        <Range value={factor} onChange={(v) => setFactor(clamp(v))} min={lo} max={hi} step={0.05} />
        <NumberInput value={factor} onChange={(v) => setFactor(clamp(v))} min={lo} max={hi} step={0.05} />
      </Field>
      <div className="text-sm">
        Duração final: <span className="font-semibold tabular-nums">{formatTime(finalDuration)}</span>
      </div>
      <Toggle checked={pitch} onChange={setPitch} label="Manter o tom do áudio (correção de tom)" disabled={removeAudio || !version.has_audio} />
      {pitch && !removeAudio && version.has_audio && (factor < 0.5 || factor > 2) && (
        <Notice tone="warn">Fora de 0.5x–2x a correção de tom pode produzir artefactos sonoros.</Notice>
      )}
      <Toggle checked={removeAudio} onChange={setRemoveAudio} label="Remover a faixa de áudio" disabled={!version.has_audio} />
      <Toggle checked={useSegment} onChange={setUseSegment} label="Aplicar só a um segmento" />
      {useSegment && (
        <div className="grid grid-cols-2 gap-3">
          <Field label="Início do segmento, s">
            <NumberInput value={segStart} onChange={setSegStart} min={0} max={D} invalid={badSegment} />
            <Button size="sm" variant="outline" onClick={() => setSegStart(now(videoRef))}>Instante atual</Button>
          </Field>
          <Field label="Fim do segmento, s">
            <NumberInput value={segEnd} onChange={setSegEnd} min={0} max={D} invalid={badSegment} />
            <Button size="sm" variant="outline" onClick={() => setSegEnd(now(videoRef))}>Instante atual</Button>
          </Field>
        </div>
      )}
      <Notice>A pré-visualização usa a velocidade do reprodutor do browser, sem processamento no servidor.</Notice>
      <ApplyBar
        disabled={factor === 1 || tooLong || badSegment}
        busy={busy}
        reason={
          tooLong
            ? `O vídeo resultante teria ${Math.round(finalDuration)} s; o máximo do seu perfil é ${profile.maxDurationSec} s.`
            : badSegment
              ? "O segmento tem de ter pelo menos 0,1 s."
              : null
        }
        onClick={() =>
          apply("video_speed", {
            factor,
            pitch,
            removeAudio,
            segment: useSegment ? { start: segStart, end: segEnd } : null,
          })
        }
      />
    </div>
  );
}

// ------------------------------------------------------------------ UC-VID-004 Legendas e texto
const FONTS = ["Noto Sans", "Noto Serif", "DejaVu Sans", "Liberation Sans", "Liberation Serif"];

export function TextPanel({ version, profile, videoRef, setPreview, apply, busy, access }: PanelProps) {
  const D = version.duration;
  const [blocks, setBlocks] = useState<TextBlock[]>([]);
  const [mode, setMode] = useState<"hardcode" | "softsub">("hardcode");
  const [importError, setImportError] = useState<string | null>(null);
  const [selected, setSelected] = useState(0);
  const fileRef = useRef<HTMLInputElement | null>(null);
  const limit = profile.maxTextBlocks;

  useEffect(() => setPreview({ kind: "text", blocks }), [blocks, setPreview]);

  const add = (partial?: Partial<TextBlock>) => {
    const t = now(videoRef);
    const b: TextBlock = { text: "Texto", start: t, end: Math.min(D, t + 2), x: 0.5, y: 0.85, size: 0.06, color: "#FFFFFF", font: "Noto Sans", bold: false, ...partial };
    setBlocks((prev) => [...prev, b]);
    setSelected(blocks.length);
  };
  const update = (i: number, patch: Partial<TextBlock>) => setBlocks(blocks.map((b, j) => (j === i ? { ...b, ...patch } : b)));
  const invalidIdx = blocks.findIndex((b) => !(b.start < b.end) || b.end > D + 0.001 || !b.text.trim()); // REQ-VID-TXT-011
  const overLimit = limit !== null && blocks.length > limit; // REQ-VID-TXT-007
  const cur = blocks[selected];

  const importFile = async (file: File) => {
    setImportError(null);
    try {
      const imported = await parseSubtitleFile(access, file); // REQ-VID-TXT-002/009
      setBlocks((prev) => [
        ...prev,
        ...imported.map((b) => ({ ...b, end: Math.min(b.end, D), x: 0.5, y: 0.88, size: 0.05, color: "#FFFFFF", font: "Noto Sans", bold: false })),
      ]);
    } catch (e) {
      setImportError(videoErrorMessage(e, "Ficheiro de legendas corrompido ou formato não suportado."));
    }
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        <Button size="sm" onClick={() => add()} disabled={limit !== null && blocks.length >= limit}>
          Adicionar bloco no instante atual
        </Button>
        <Button size="sm" variant="outline" onClick={() => fileRef.current?.click()}>
          Importar legendas (.srt / .vtt)
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept=".srt,.vtt,text/vtt"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) importFile(f);
            e.target.value = "";
          }}
        />
      </div>
      {importError && <Notice tone="error">{importError}</Notice>}
      <div className="text-xs text-muted-foreground">
        Blocos: {blocks.length}
        {limit !== null ? ` / ${limit}` : ""}
      </div>
      {overLimit && <Notice tone="warn">O seu perfil permite no máximo {limit} blocos de texto por vídeo.</Notice>}

      <ul className="flex flex-col gap-1 max-h-40 overflow-auto">
        {blocks.map((b, i) => (
          <li key={i} className={`flex items-center justify-between rounded border px-2 py-1 text-xs ${i === selected ? "border-primary" : ""} ${i === invalidIdx ? "border-red-500" : ""}`}>
            <button className="truncate text-left flex-1" onClick={() => setSelected(i)}>
              <span className="font-mono">{formatTime(b.start)}–{formatTime(b.end)}</span> {b.text}
            </button>
            <button className="text-red-600 pl-2" onClick={() => setBlocks(blocks.filter((_, j) => j !== i))}>Remover</button>
          </li>
        ))}
      </ul>

      {cur && (
        <div className="flex flex-col gap-2 rounded-md border p-2">
          <Field label="Texto">
            <textarea className="min-h-16 rounded-md border border-input bg-transparent p-2 text-sm" value={cur.text} onChange={(e) => update(selected, { text: e.target.value })} />
          </Field>
          <div className="grid grid-cols-2 gap-2">
            <Field label="Entrada (t_in), s">
              <NumberInput value={cur.start} onChange={(v) => update(selected, { start: v })} min={0} max={D} invalid={!(cur.start < cur.end)} />
            </Field>
            <Field label="Saída (t_out), s">
              <NumberInput value={cur.end} onChange={(v) => update(selected, { end: v })} min={0} max={D} invalid={!(cur.start < cur.end) || cur.end > D} />
            </Field>
            <Field label="Posição horizontal">
              <Range value={cur.x} onChange={(v) => update(selected, { x: v })} min={0} max={1} step={0.01} />
            </Field>
            <Field label="Posição vertical">
              <Range value={cur.y} onChange={(v) => update(selected, { y: v })} min={0} max={1} step={0.01} />
            </Field>
            <Field label="Tamanho">
              <Range value={cur.size} onChange={(v) => update(selected, { size: v })} min={0.02} max={0.3} step={0.005} />
            </Field>
            <Field label="Cor">
              <input type="color" className="h-9 w-full rounded-md border" value={cur.color} onChange={(e) => update(selected, { color: e.target.value.toUpperCase() })} />
            </Field>
            <Field label="Fonte">
              <select className="h-9 rounded-md border border-input bg-transparent px-2 text-sm" value={cur.font} onChange={(e) => update(selected, { font: e.target.value })}>
                {FONTS.map((f) => (
                  <option key={f} value={f}>{f}</option>
                ))}
              </select>
            </Field>
            <div className="flex items-end pb-2">
              <Toggle checked={cur.bold} onChange={(v) => update(selected, { bold: v })} label="Negrito" />
            </div>
          </div>
        </div>
      )}

      <Field label="Modo de gravação">
        <div className="flex gap-2">
          <Button size="sm" variant={mode === "hardcode" ? "default" : "outline"} onClick={() => setMode("hardcode")}>
            Hardcode (na imagem)
          </Button>
          <Button size="sm" variant={mode === "softsub" ? "default" : "outline"} disabled={!profile.softSub} onClick={() => setMode("softsub")}>
            Soft-sub (faixa separada)
          </Button>
        </div>
      </Field>
      {!profile.softSub && <Notice>A exportação de legendas em faixa separada é exclusiva de contas Premium.</Notice>}
      {mode === "softsub" && <Notice>No modo Soft-sub, posição, cor e fonte são decididas pelo leitor de vídeo.</Notice>}

      <ApplyBar
        disabled={blocks.length === 0 || invalidIdx >= 0 || overLimit}
        busy={busy}
        reason={invalidIdx >= 0 ? `O bloco ${invalidIdx + 1} é inválido: texto vazio ou instantes fora do vídeo (início < fim).` : null}
        onClick={() => apply("video_text", { mode, blocks })}
      />
    </div>
  );
}

// ------------------------------------------------------------------ UC-VID-005 Filtros de cor
const PRESETS = [
  { id: "none", label: "Nenhum" },
  { id: "sepia", label: "Sépia" },
  { id: "bw", label: "Preto & Branco" },
  { id: "high_contrast", label: "Alto Contraste" },
  { id: "cinematic", label: "Cinematográfico" },
];

// Aproximação CSS dos filtros do servidor, para pré-visualização (REQ-VID-COL-001)
export function cssFilter(preset: string, intensity: number, m: { brightness: number; contrast: number; saturation: number }) {
  const i = intensity / 100;
  const parts: string[] = [];
  if (m.brightness !== 0) parts.push(`brightness(${1 + m.brightness})`);
  if (m.contrast !== 1) parts.push(`contrast(${m.contrast})`);
  if (m.saturation !== 1) parts.push(`saturate(${m.saturation})`);
  if (preset === "sepia") parts.push(`sepia(${i})`);
  if (preset === "bw") parts.push(`grayscale(${i})`);
  if (preset === "high_contrast") parts.push(`contrast(${1 + 0.6 * i}) saturate(${1 + 0.15 * i})`);
  if (preset === "cinematic") parts.push(`contrast(${1 + 0.1 * i}) saturate(${1 - 0.15 * i}) hue-rotate(${-8 * i}deg)`);
  return parts.join(" ") || "none";
}

export function ColorPanel({ profile, setPreview, apply, busy, access }: PanelProps) {
  const [preset, setPreset] = useState("none");
  const [intensity, setIntensity] = useState(100);
  const [manual, setManual] = useState({ brightness: 0, contrast: 1, saturation: 1, gamma: 1 });
  const [lut, setLut] = useState<{ lutId: string; name: string } | null>(null);
  const [lutError, setLutError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => setPreview({ kind: "color", filter: cssFilter(preset, intensity, manual) }), [preset, intensity, manual, setPreview]);

  const manualChanged = manual.brightness !== 0 || manual.contrast !== 1 || manual.saturation !== 1 || manual.gamma !== 1;
  const nothing = (preset === "none" || intensity === 0) && !manualChanged && !lut;

  const importLut = async (file: File) => {
    setLutError(null);
    try {
      setLut(await uploadLut(access, file)); // REQ-VID-COL-002/009
    } catch (e) {
      setLutError(videoErrorMessage(e, "Ficheiro LUT inválido ou corrompido."));
    }
  };

  return (
    <div className="flex flex-col gap-3">
      <Field label="Filtro predefinido">
        <div className="grid grid-cols-2 gap-1">
          {PRESETS.map((p) => (
            <Button key={p.id} size="sm" variant={preset === p.id ? "default" : "outline"} onClick={() => setPreset(p.id)}>
              {p.label}
            </Button>
          ))}
        </div>
      </Field>
      <Field label={`Intensidade: ${intensity}%`}>
        <Range value={intensity} onChange={setIntensity} min={0} max={100} step={1} />
      </Field>
      <div className="grid grid-cols-2 gap-2">
        <Field label={`Brilho: ${manual.brightness.toFixed(2)}`}>
          <Range value={manual.brightness} onChange={(v) => setManual({ ...manual, brightness: v })} min={-1} max={1} step={0.01} />
        </Field>
        <Field label={`Contraste: ${manual.contrast.toFixed(2)}`}>
          <Range value={manual.contrast} onChange={(v) => setManual({ ...manual, contrast: v })} min={0} max={2} step={0.01} />
        </Field>
        <Field label={`Saturação: ${manual.saturation.toFixed(2)}`}>
          <Range value={manual.saturation} onChange={(v) => setManual({ ...manual, saturation: v })} min={0} max={3} step={0.01} />
        </Field>
        <Field label={`Gama: ${manual.gamma.toFixed(2)}`} hint="Sem pré-visualização exata">
          <Range value={manual.gamma} onChange={(v) => setManual({ ...manual, gamma: v })} min={0.1} max={3} step={0.01} />
        </Field>
      </div>
      <Button size="sm" variant="ghost" onClick={() => setManual({ brightness: 0, contrast: 1, saturation: 1, gamma: 1 })}>
        Repor ajustes manuais
      </Button>

      <Field label="LUT 3D (.cube)">
        <Button size="sm" variant="outline" disabled={!profile.lut} onClick={() => fileRef.current?.click()}>
          {lut ? `LUT: ${lut.name}` : "Importar LUT 3D"}
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept=".cube"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) importLut(f);
            e.target.value = "";
          }}
        />
      </Field>
      {!profile.lut && <Notice>A importação de LUTs 3D personalizados é exclusiva do perfil Premium.</Notice>}
      {lut && (
        <div className="flex items-center gap-2">
          <Notice>O LUT é aplicado no resultado final; a pré-visualização não o inclui.</Notice>
          <Button size="sm" variant="ghost" onClick={() => setLut(null)}>Remover</Button>
        </div>
      )}
      {lutError && <Notice tone="error">{lutError}</Notice>}

      <ApplyBar
        disabled={nothing}
        busy={busy}
        reason={nothing ? "Escolha um filtro, um ajuste manual ou um LUT." : null}
        onClick={() => apply("video_color", { preset, intensity, manual, lutId: lut?.lutId ?? null })}
      />
    </div>
  );
}
