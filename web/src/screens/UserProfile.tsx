// Read-only profile for another user (tapped from a plan's members list).
// Mirrors UserProfileView.swift: header card (avatar + name + gender/age chips),
// a Bio section, and a Credit card (attendance rate + hosted), plus a Message
// button so you can DM them from here.
import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchUsers } from "@/services/db";
import type { AppUser } from "@/types";
import { useAuth } from "@/auth/AuthContext";
import { t } from "@/i18n";
import { Chip, Spinner } from "@/components/ui";

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

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-fog bg-cream px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <span className="flex-1 truncate text-center font-medium text-ink">{t("Profile")}</span>
        <span className="w-6" />
      </div>

      {q.isLoading ? (
        <Spinner />
      ) : !u ? (
        <div className="p-6 text-inkMuted">{t("Profile unavailable")}</div>
      ) : (
        <div className="flex-1 space-y-5 overflow-y-auto px-5 pb-10 pt-4">
          {/* Header card */}
          <div className="flex items-center gap-4 rounded-card bg-shell p-4">
            <Avatar user={u} />
            <div className="min-w-0 flex-1">
              <div className="text-[20px] font-medium text-ink">{u.display_name}</div>
              {(u.gender || u.age != null) && (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {u.gender && <Chip text={t(u.gender === "female" ? "Female" : "Male")} tint="lavender" />}
                  {u.age != null && <Chip text={t("Age %lld", u.age)} tint="clay" />}
                </div>
              )}
            </div>
          </div>

          {/* Bio */}
          {u.bio && (
            <Section title={t("Bio")}>
              <div className="rounded-card bg-shell p-4 text-[14px] leading-relaxed text-ink">{u.bio}</div>
            </Section>
          )}

          {/* Credit */}
          <Section title={t("Credit")}>
            <div className="overflow-hidden rounded-card bg-shell">
              <CreditRow icon="✅" tint="bg-sageDeep/18" label={t("Attendance rate")}>
                {u.attendance_record_count && u.attendance_record_count > 0 ? (
                  <div className="text-right">
                    <div className="text-[15px] font-medium tabular-nums text-ink">
                      {Math.round(((u.attended_count ?? 0) / u.attendance_record_count) * 100)}%
                    </div>
                    <div className="text-[11px] tabular-nums text-inkMuted">
                      {u.attended_count ?? 0} / {u.attendance_record_count}
                    </div>
                  </div>
                ) : (
                  <span className="text-[15px] font-medium text-inkMuted">—</span>
                )}
              </CreditRow>
              <div className="ml-[50px] border-t border-fog" />
              <CreditRow icon="👑" tint="bg-clay/18" label={t("Hosted")}>
                <span className="text-[15px] font-medium tabular-nums text-ink">{u.hosted_count ?? 0}</span>
              </CreditRow>
            </div>
          </Section>

          {!isSelf && (
            <button className="pin-btn-primary" onClick={() => nav(`/dm/${u.id}`)}>
              {t("Message")}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

function Avatar({ user }: { user: AppUser }) {
  // Default to the app logo (puffin) when there's no photo.
  return <img src={user.avatar_url || "/icon.png"} alt="" className="h-[72px] w-[72px] rounded-full object-cover" />;
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="space-y-2">
      <div className="text-[12px] font-semibold uppercase tracking-wide text-inkMuted">{title}</div>
      {children}
    </div>
  );
}

function CreditRow({ icon, tint, label, children }: { icon: string; tint: string; label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3.5">
      <span className={`flex h-[26px] w-[26px] items-center justify-center rounded-full text-[13px] ${tint}`}>{icon}</span>
      <span className="text-[14px] text-ink">{label}</span>
      <span className="ml-auto">{children}</span>
    </div>
  );
}
