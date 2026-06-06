// Mirrors ProfileView.swift: header, avatar, bio, credits (attendance + hosted),
// how-it-works, edit (name/bio/avatar), language, sign out.
import { useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { updateProfile, uploadAvatar } from "@/services/db";
import { useAuth } from "@/auth/AuthContext";
import { t, currentLang, setLang } from "@/i18n";
import { Wordmark } from "@/components/ui";

export function Profile() {
  const { user, isSignedIn, refresh, signOut } = useAuth();
  const nav = useNavigate();
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(user?.display_name ?? "");
  const [bio, setBio] = useState(user?.bio ?? "");
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  if (!user) return null;

  // Guest / anonymous user — show sign-up prompt
  if (!isSignedIn) {
    return (
      <div className="flex min-h-full flex-col items-center justify-center px-8 pb-16 pt-8 text-center">
        <Wordmark size={36} />
        {/* The guest is still a diner who can join plans — show their profile here too. */}
        <img src={user.avatar_url || "/icon.png"} alt="" className="mt-7 h-20 w-20 rounded-full object-cover" />
        <div className="mt-3 text-[20px] font-medium text-ink">{user.display_name}</div>
        <p className="mt-1 font-subtitle text-[14px] text-inkMuted">
          {t("You're browsing as a guest")}
        </p>

        {/* What they CAN do */}
        <div className="mt-4 w-full max-w-xs rounded-card bg-shell p-4 text-left">
          <div className="text-[12px] font-semibold uppercase tracking-wide text-sageDeep">{t("✓ Available as guest")}</div>
          <ul className="mt-2 space-y-1 text-[13px] text-ink">
            <li>{t("Browse restaurants and deals")}</li>
            <li>{t("View and join dining plans")}</li>
            <li>{t("Chat inside plans you've joined")}</li>
          </ul>
        </div>

        {/* What they're missing */}
        <div className="mt-3 w-full max-w-xs rounded-card bg-shell p-4 text-left">
          <div className="text-[12px] font-semibold uppercase tracking-wide text-clay">{t("↑ With a free account")}</div>
          <ul className="mt-2 space-y-1 text-[13px] text-ink">
            <li>{t("Create your own dining plans")}</li>
            <li>{t("Send direct messages")}</li>
            <li>{t("Track attendance and history")}</li>
          </ul>
        </div>

        <div className="mt-6 w-full max-w-xs space-y-3">
          <button className="pin-btn-primary" onClick={() => nav("/signin")}>
            {t("Sign up — it's free")}
          </button>
          <button className="pin-btn-secondary" onClick={() => nav("/signin")}>
            {t("I already have an account")}
          </button>
        </div>
        <div className="mt-8 w-full max-w-xs">
          <div className="text-[12px] font-semibold uppercase tracking-wide text-inkMuted">{t("Settings")}</div>
          <div className="mt-2 flex gap-2">
            {(["en", "zh-Hans", "zh-Hant"] as const).map((l) => (
              <button
                key={l}
                onClick={() => setLang(l)}
                className={`rounded-full px-3 py-1.5 text-[13px] font-semibold ${currentLang() === l ? "bg-clay text-cream" : "bg-shell text-ink"}`}
              >
                {l === "en" ? "English" : l === "zh-Hans" ? "简体" : "繁體"}
              </button>
            ))}
          </div>
        </div>
      </div>
    );
  }

  const rate = user.attendance_record_count && user.attendance_record_count > 0
    ? Math.round(((user.attended_count ?? 0) / user.attendance_record_count) * 100)
    : null;

  async function pickAvatar(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !user) return;
    setBusy(true);
    try {
      const url = await uploadAvatar(user.id, file);
      await updateProfile(user.id, { avatar_url: url });
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  async function save() {
    setBusy(true);
    try {
      await updateProfile(user!.id, { display_name: name.trim() || user!.display_name, bio: bio.slice(0, 150) });
      await refresh();
      setEditing(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="px-5 pb-10 pt-3">
      <h1 className="font-accent text-[40px] italic text-clayDeep">{t("Me.")}</h1>
      <p className="font-subtitle text-[13px] text-inkMuted">{t("How my mates see me on PinTable.")}</p>

      {/* Profile card */}
      <div className="mt-5 flex items-center gap-4 rounded-card bg-shell p-4">
        <button onClick={() => editing && fileRef.current?.click()} className="relative">
          <img src={user.avatar_url || "/icon.png"} alt="" className="h-16 w-16 rounded-full object-cover" />
          {editing && <span className="absolute -bottom-1 -right-1 rounded-full bg-clay px-1.5 text-[11px] text-cream">✎</span>}
        </button>
        <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={pickAvatar} />
        <div className="min-w-0 flex-1">
          {editing ? (
            <input className="pin-field" value={name} onChange={(e) => setName(e.target.value)} />
          ) : (
            <div className="text-[20px] font-medium text-ink">{user.display_name}</div>
          )}
          <div className="truncate text-[13px] text-inkMuted">{user.email || "—"}</div>
        </div>
        {!editing && (
          <button className="text-[13px] font-semibold text-clay" onClick={() => { setName(user.display_name); setBio(user.bio ?? ""); setEditing(true); }}>
            {t("Edit profile")}
          </button>
        )}
      </div>

      {editing && (
        <div className="mt-3">
          <textarea
            className="pin-field min-h-[72px]"
            placeholder={t("Tell others a bit about yourself")}
            value={bio}
            maxLength={150}
            onChange={(e) => setBio(e.target.value)}
          />
          <div className="mt-2 flex gap-2">
            <button className="pin-btn-primary" disabled={busy} onClick={save}>{t("Save")}</button>
            <button className="pin-btn-secondary" onClick={() => setEditing(false)}>{t("Cancel")}</button>
          </div>
        </div>
      )}

      {!editing && user.bio && (
        <div className="mt-3 rounded-card bg-shell p-4 text-[14px] text-ink">{user.bio}</div>
      )}

      {/* Credits */}
      <div className="mt-5 grid grid-cols-2 gap-3">
        <Stat label={t("Attendance")} value={rate !== null ? `${rate}%` : `${user.attended_count ?? 0} / ${user.attendance_record_count ?? 0}`} />
        <Stat label={t("Hosted")} value={`${user.hosted_count ?? 0}`} />
      </div>

      {/* How it works */}
      <div className="mt-7 rounded-card bg-shell p-4">
        <div className="mb-3 text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{t("How it works")}</div>
        <HowRow n="1" text={t("Browse restaurants and see who's already planning to dine.")} />
        <HowRow n="2" text={t("Pin a plan — set time, group size, and goal.")} />
        <HowRow n="3" text={t("Chat in real-time with your mates before heading over.")} />
      </div>

      {/* Settings: language */}
      <div className="mt-7 text-[13px] font-semibold uppercase tracking-wide text-inkMuted">{t("Settings")}</div>
      <div className="mt-2 flex gap-2">
        {(["en", "zh-Hans", "zh-Hant"] as const).map((l) => (
          <button
            key={l}
            onClick={() => setLang(l)}
            className={`rounded-full px-3 py-1.5 text-[13px] font-semibold ${currentLang() === l ? "bg-clay text-cream" : "bg-shell text-ink"}`}
          >
            {l === "en" ? "English" : l === "zh-Hans" ? "简体" : "繁體"}
          </button>
        ))}
      </div>

      <button className="pin-btn-secondary mt-8" onClick={signOut}>{t("Sign out")}</button>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-card bg-shell p-4 text-center">
      <div className="text-[24px] font-medium text-clayDeep">{value}</div>
      <div className="text-[12px] text-inkMuted">{label}</div>
    </div>
  );
}

function HowRow({ n, text }: { n: string; text: string }) {
  return (
    <div className="flex items-start gap-3 py-1.5">
      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-clay/15 text-[12px] font-semibold text-clayDeep">{n}</span>
      <span className="text-[14px] text-ink">{text}</span>
    </div>
  );
}
