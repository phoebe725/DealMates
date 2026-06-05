// Shared primitives mirroring PinControls.swift / PintableWordmark.swift.
import type { ReactNode } from "react";
import { currentLang } from "@/i18n";

export function Wordmark({ size = 22 }: { size?: number }) {
  const zh = currentLang().startsWith("zh");
  const [a, b] = zh ? ["拼", "桌"] : ["Pin", "Table"];
  return (
    <span className="font-accent italic font-semibold" style={{ fontSize: size }}>
      <span className="text-clay">{a}</span>
      <span className="text-ink">{b}</span>
    </span>
  );
}

const TINTS: Record<string, string> = {
  clay: "bg-clay/15 text-clayDeep",
  sage: "bg-sageDeep/15 text-sageDeep",
  sun: "bg-sunDeep/15 text-sunDeep",
  lavender: "bg-lavenderDeep/15 text-lavenderDeep",
  ink: "bg-shell text-inkMuted",
};

export function Chip({
  text,
  icon,
  tint = "clay",
}: {
  text: string;
  icon?: ReactNode;
  tint?: keyof typeof TINTS;
}) {
  return (
    <span className={`pin-chip ${TINTS[tint]}`}>
      {icon}
      {text}
    </span>
  );
}

export function EmptyState({
  title,
  message,
  emoji = "🍽️",
}: {
  title: string;
  message?: string;
  emoji?: string;
}) {
  return (
    <div className="flex flex-col items-center px-8 pt-16 text-center">
      <div className="mb-5 flex h-[88px] w-[88px] items-center justify-center rounded-full bg-peach/30 text-4xl">
        {emoji}
      </div>
      <div className="font-sans text-[22px] text-ink">{title}</div>
      {message && <p className="mt-2 max-w-xs text-[14px] leading-relaxed text-inkMuted">{message}</p>}
    </div>
  );
}

export function Spinner({ label }: { label?: string }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-3 py-20 text-inkMuted">
      <div className="h-6 w-6 animate-spin rounded-full border-2 border-inkMuted/30 border-t-inkMuted" />
      {label && <div className="text-[14px]">{label}</div>}
    </div>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex gap-0.5 rounded-2xl bg-shell p-1">
      {options.map((o) => {
        const sel = o.value === value;
        return (
          <button
            key={o.value}
            onClick={() => onChange(o.value)}
            className={`flex-1 rounded-xl py-2 text-[14px] font-semibold transition ${
              sel ? "bg-cream text-ink shadow-sm" : "text-inkMuted"
            }`}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
