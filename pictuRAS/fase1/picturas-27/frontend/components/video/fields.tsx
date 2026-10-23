"use client";

import { ReactNode } from "react";

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="font-medium">{label}</span>
      {children}
      {hint && <span className="text-xs text-muted-foreground">{hint}</span>}
    </label>
  );
}

export function NumberInput({
  value,
  onChange,
  min,
  max,
  step = 0.001,
  invalid,
}: {
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
  step?: number;
  invalid?: boolean;
}) {
  return (
    <input
      type="number"
      className={`h-9 rounded-md border bg-transparent px-2 text-sm tabular-nums ${invalid ? "border-red-500 text-red-600" : "border-input"}`}
      value={Number.isFinite(value) ? value : 0}
      min={min}
      max={max}
      step={step}
      onChange={(e) => onChange(Number(e.target.value))}
    />
  );
}

export function Range({
  value,
  onChange,
  min,
  max,
  step,
}: {
  value: number;
  onChange: (v: number) => void;
  min: number;
  max: number;
  step: number;
}) {
  return (
    <input
      type="range"
      className="w-full accent-primary"
      value={value}
      min={min}
      max={max}
      step={step}
      onChange={(e) => onChange(Number(e.target.value))}
    />
  );
}

export function Toggle({ checked, onChange, label, disabled }: { checked: boolean; onChange: (v: boolean) => void; label: string; disabled?: boolean }) {
  return (
    <label className={`flex items-center gap-2 text-sm ${disabled ? "opacity-50" : ""}`}>
      <input type="checkbox" className="accent-primary size-4" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}

export function Notice({ children, tone = "info" }: { children: ReactNode; tone?: "info" | "warn" | "error" }) {
  const cls =
    tone === "error"
      ? "border-red-300 bg-red-50 text-red-800 dark:bg-red-950/40 dark:text-red-200"
      : tone === "warn"
        ? "border-amber-300 bg-amber-50 text-amber-900 dark:bg-amber-950/40 dark:text-amber-200"
        : "border-sky-300 bg-sky-50 text-sky-900 dark:bg-sky-950/40 dark:text-sky-200";
  return <div className={`rounded-md border px-3 py-2 text-xs ${cls}`}>{children}</div>;
}
