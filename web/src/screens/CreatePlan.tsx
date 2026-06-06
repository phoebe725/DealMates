// Mirrors CreatePlanView.swift: When (ASAP / scheduled / flexible) · Group size
// · Open to · Notes. Builds the same Plan row (same expires_at rules) and
// inserts it, then opens the new plan.
import { useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchRestaurant, createPlan } from "@/services/db";
import { restaurantName, type GenderPreference, type Plan, type TimeType } from "@/types";
import { generateEventCode } from "@/lib/eventCode";
import { t } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { Segmented, Spinner } from "@/components/ui";

function uuid() {
  return crypto.randomUUID();
}

export function CreatePlan() {
  const nav = useNavigate();
  const [params] = useSearchParams();
  const restaurantId = params.get("restaurant") ?? "";
  const { user } = useAuth();

  const r = useQuery({ queryKey: ["restaurant", restaurantId], queryFn: () => fetchRestaurant(restaurantId), enabled: !!restaurantId });

  const [timeType, setTimeType] = useState<TimeType>("asap");
  const [scheduledAt, setScheduledAt] = useState(() => {
    const d = new Date(Date.now() + 3600_000);
    d.setSeconds(0, 0);
    return d.toISOString().slice(0, 16); // for <input type=datetime-local>
  });
  const [flexDay, setFlexDay] = useState<"weekday" | "weekend">("weekday");
  const [flexMeal, setFlexMeal] = useState<"lunch" | "dinner">("lunch");
  const [needed, setNeeded] = useState(3);
  const [joined, setJoined] = useState(1);
  const [pref, setPref] = useState<GenderPreference>("any");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Guest / anonymous user — prompt sign-up before creating a plan
  if (user?.is_anonymous) {
    return (
      <div className="flex min-h-full flex-col items-center justify-center px-8 text-center">
        <div className="text-[48px]">🍽️</div>
        <h1 className="mt-4 font-sans text-[22px] font-light text-ink">
          {t("Create a free account to start a plan")}
        </h1>
        <p className="mt-2 text-[14px] text-inkMuted">
          {t("You can still join plans as a guest — no account needed for that.")}
        </p>
        <button className="pin-btn-primary mt-8 w-full max-w-xs" onClick={() => nav("/signin")}>
          {t("Sign up or log in")}
        </button>
        <button className="mt-3 text-[14px] text-clay" onClick={() => nav(-1)}>
          {t("Cancel")}
        </button>
      </div>
    );
  }

  if (r.isLoading) return <Spinner />;
  const rest = r.data;
  if (!rest || !user) return <div className="p-6 text-inkMuted">Pick a restaurant from Discover first.</div>;

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const now = new Date();
      let schedDate: Date;
      let expiry: Date;
      if (timeType === "asap") {
        schedDate = now;
        expiry = new Date(now.getTime() + 2 * 3600_000);
      } else if (timeType === "scheduled") {
        schedDate = new Date(scheduledAt);
        expiry = new Date(schedDate.getTime() + 3600_000);
      } else {
        schedDate = now;
        expiry = new Date(now.getTime() + 7 * 24 * 3600_000);
      }
      const plan: Plan = {
        id: uuid(),
        restaurant_id: rest!.id,
        restaurant_name: rest!.name,
        creator_id: user!.id,
        creator_name: user!.display_name,
        creator_avatar_url: user!.avatar_url ?? null,
        is_asap: timeType === "asap",
        scheduled_at: schedDate.toISOString(),
        needed_people: needed,
        current_people: Math.min(joined, needed),
        member_ids: [user!.id],
        notes: notes.trim(),
        expires_at: expiry.toISOString(),
        reported_by: [],
        time_type: timeType,
        flex_day: timeType === "flexible" ? flexDay : null,
        flex_meal: timeType === "flexible" ? flexMeal : null,
        gender_preference: pref,
        attendance_confirmed_at: null,
        created_at: now.toISOString(),
        event_code: generateEventCode(),
      };
      await createPlan(plan);
      nav(`/plan/${plan.id}`, { replace: true });
    } catch (e: any) {
      setError(e?.message ?? "Could not create.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="px-5 pb-10 pt-3">
      <button onClick={() => nav(-1)} className="mb-2 text-[22px] text-ink">‹</button>
      <h1 className="leading-tight">
        <span className="font-accent text-[36px] italic text-clayDeep">{t("Create a table")}</span>
      </h1>
      <p className="font-subtitle text-[14px] text-inkMuted">{t("At %@.", restaurantName(rest))}</p>

      <Section title={t("When")}>
        <Segmented
          value={timeType}
          onChange={setTimeType}
          options={[
            { value: "asap", label: t("ASAP") },
            { value: "scheduled", label: t("Scheduled") },
            { value: "flexible", label: t("Flexible") },
          ]}
        />
        {timeType === "scheduled" && (
          <input
            type="datetime-local"
            className="pin-field mt-3"
            value={scheduledAt}
            onChange={(e) => setScheduledAt(e.target.value)}
          />
        )}
        {timeType === "flexible" && (
          <div className="mt-3 space-y-3">
            <Segmented value={flexDay} onChange={setFlexDay} options={[{ value: "weekday", label: t("Weekday") }, { value: "weekend", label: t("Weekend") }]} />
            <Segmented value={flexMeal} onChange={setFlexMeal} options={[{ value: "lunch", label: t("Lunch") }, { value: "dinner", label: t("Dinner") }]} />
          </div>
        )}
      </Section>

      <Section title={t("Group size")}>
        <Stepper label={t("Total needed")} value={needed} min={1} max={10} onChange={(v) => { setNeeded(v); if (joined > v) setJoined(v); }} />
        <Stepper label={t("Already joined")} value={joined} min={1} max={needed} onChange={setJoined} />
      </Section>

      <Section title={t("Open to")}>
        <Segmented
          value={pref}
          onChange={setPref}
          options={[
            { value: "any", label: t("Anyone") },
            { value: "female", label: t("Female") },
            { value: "male", label: t("Male") },
          ]}
        />
      </Section>

      <Section title={t("Notes (optional)")}>
        <textarea
          className="pin-field min-h-[80px]"
          placeholder={t("e.g. Looking for 2 more for lunch deal")}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
        />
      </Section>

      {error && <p className="mt-2 rounded-pin bg-clay/12 p-3 text-[13px] text-ink">{error}</p>}
      <button className="pin-btn-primary mt-6" disabled={busy} onClick={submit}>
        {busy ? "…" : t("Create a table")}
      </button>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-6">
      <div className="mb-2 text-[14px] font-medium text-ink">{title}</div>
      {children}
    </div>
  );
}

function Stepper({ label, value, min, max, onChange }: { label: string; value: number; min: number; max: number; onChange: (v: number) => void }) {
  return (
    <div className="flex items-center py-1.5">
      <span className="text-[14px] text-ink">{label}</span>
      <div className="ml-auto flex items-center gap-3">
        <span className="min-w-[64px] text-right text-[14px] font-medium tabular-nums text-ink">{t("%lld people", value)}</span>
        <button className="h-7 w-7 rounded-full bg-shell text-ink disabled:opacity-40" disabled={value <= min} onClick={() => onChange(value - 1)}>−</button>
        <button className="h-7 w-7 rounded-full bg-shell text-ink disabled:opacity-40" disabled={value >= max} onClick={() => onChange(value + 1)}>+</button>
      </div>
    </div>
  );
}
