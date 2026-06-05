// Mirrors MyPlansView.swift: Active / Ready to go / Completed buckets over the
// plans the user belongs to, default ordering, tap to open.
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchMyPlans, defaultPlanOrder } from "@/services/db";
import { needsMorePeople, type Plan } from "@/types";
import { t } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { Chip, EmptyState, Segmented, Spinner } from "@/components/ui";

type Bucket = "active" | "ready" | "completed";

function bucketOf(p: Plan): Bucket {
  if (p.attendance_confirmed_at) return "completed";
  return needsMorePeople(p) > 0 ? "active" : "ready";
}

function timeLabel(p: Plan) {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible")
    return `${t(p.flex_day === "weekend" ? "Weekend" : "Weekday")} ${t(p.flex_meal === "dinner" ? "Dinner" : "Lunch")}`;
  return new Date(p.scheduled_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

export function MyPlans() {
  const nav = useNavigate();
  const { user } = useAuth();
  const [bucket, setBucket] = useState<Bucket>("active");

  const q = useQuery({
    queryKey: ["myPlans", user?.id],
    queryFn: () => fetchMyPlans(user!.id),
    enabled: !!user,
  });

  const visible = useMemo(
    () => (q.data ?? []).filter((p) => bucketOf(p) === bucket).sort(defaultPlanOrder),
    [q.data, bucket],
  );

  return (
    <div className="flex flex-col">
      <div className="px-5 pb-3 pt-3">
        <h1 className="leading-tight">
          <span className="font-sans text-[28px] font-light text-ink">{t("My ")}</span>
          <span className="font-accent text-[38px] italic text-clayDeep">{t("plans.")}</span>
        </h1>
        <div className="mt-4">
          <Segmented
            value={bucket}
            onChange={setBucket}
            options={[
              { value: "active", label: t("Active") },
              { value: "ready", label: t("Ready to go") },
              { value: "completed", label: t("Completed") },
            ]}
          />
        </div>
      </div>

      {q.isLoading ? (
        <Spinner />
      ) : visible.length === 0 ? (
        <EmptyState
          title={t(bucket === "completed" ? "No plans wrapped up yet" : bucket === "ready" ? "Nothing ready to go yet" : "No plans yet")}
          emoji="📅"
        />
      ) : (
        <div className="space-y-3 px-5 pb-6">
          {visible.map((p) => {
            const need = needsMorePeople(p);
            return (
              <button key={p.id} onClick={() => nav(`/plan/${p.id}`)} className="block w-full rounded-card bg-shell p-4 text-left">
                <div className="text-[16px] font-medium text-ink">{p.restaurant_name}</div>
                <div className="mt-2 flex items-center">
                  <span className="text-[13px] text-inkMuted">🕐 {timeLabel(p)}</span>
                  <span className="ml-auto">
                    {p.attendance_confirmed_at ? (
                      <Chip text={t("Done")} tint="sage" />
                    ) : need > 0 ? (
                      <Chip text={t("%lld/%lld joined", p.current_people, p.needed_people)} />
                    ) : (
                      <Chip text={t("Ready")} tint="sage" />
                    )}
                  </span>
                </div>
                {p.created_at && (
                  <div className="mt-1 text-[11px] text-inkMuted">
                    {t("Created %@", new Date(p.created_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }))}
                  </div>
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
