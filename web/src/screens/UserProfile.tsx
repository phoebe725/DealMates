// Read-only profile for another user (tapped from a plan's members list).
// Shows avatar, name, bio, reliability credits, and a Message button to DM them.
import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchUsers } from "@/services/db";
import { useAuth } from "@/auth/AuthContext";
import { t } from "@/i18n";
import { Spinner } from "@/components/ui";

export function UserProfile() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const { user } = useAuth();

  const q = useQuery({
    queryKey: ["user", id],
    queryFn: () => fetchUsers([id]).then((u) => u[0] ?? null),
    enabled: !!id,
  });
  const u = q.data ?? null;
  const isSelf = !!user && user.id === id;

  const rate =
    u?.attendance_record_count && u.attendance_record_count > 0
      ? Math.round(((u.attended_count ?? 0) / u.attendance_record_count) * 100)
      : null;

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-fog bg-shell px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <span className="flex-1 truncate text-center font-medium text-ink">{u?.display_name ?? ""}</span>
        <span className="w-6" />
      </div>

      {q.isLoading ? (
        <Spinner />
      ) : !u ? (
        <div className="p-6 text-inkMuted">{t("No restaurants yet")}</div>
      ) : (
        <div className="flex-1 overflow-y-auto px-5 pb-10 pt-5">
          <div className="flex items-center gap-4 rounded-card bg-shell p-4">
            {u.avatar_url ? (
              <img src={u.avatar_url} alt="" className="h-16 w-16 rounded-full object-cover" />
            ) : (
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-clay text-2xl text-cream">
                {u.display_name.charAt(0).toUpperCase()}
              </div>
            )}
            <div className="min-w-0 flex-1">
              <div className="text-[20px] font-medium text-ink">{u.display_name}</div>
              {u.bio && <div className="mt-0.5 text-[13px] text-inkMuted">{u.bio}</div>}
            </div>
          </div>

          <div className="mt-5 grid grid-cols-2 gap-3">
            <Stat
              label={t("Attendance")}
              value={rate !== null ? `${rate}%` : `${u.attended_count ?? 0} / ${u.attendance_record_count ?? 0}`}
            />
            <Stat label={t("Hosted")} value={`${u.hosted_count ?? 0}`} />
          </div>

          {!isSelf && (
            <button className="pin-btn-primary mt-7" onClick={() => nav(`/dm/${u.id}`)}>
              {t("Message")}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-card bg-shell p-4">
      <div className="text-[22px] font-semibold text-ink">{value}</div>
      <div className="text-[12px] uppercase tracking-wide text-inkMuted">{label}</div>
    </div>
  );
}
