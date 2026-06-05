// Temporary in-progress screens for the tabs/details not yet ported. These are
// scaffolds for the phased build — NOT final mock screens. Replaced screen by
// screen (Plan detail, chat, create, My Plans, Messages…).
import { useNavigate, useParams } from "react-router-dom";
import { useAuth } from "@/auth/AuthContext";
import { setLang, currentLang, t } from "@/i18n";
import { Wordmark } from "@/components/ui";

function Header({ title }: { title: string }) {
  return <h1 className="px-5 pb-2 pt-3 font-sans text-[28px] font-light text-ink">{title}</h1>;
}

function Building({ name }: { name: string }) {
  return (
    <div className="flex flex-col items-center px-8 pt-16 text-center text-inkMuted">
      <Wordmark size={26} />
      <p className="mt-6 text-[15px]">“{name}” is being ported next.</p>
      <p className="mt-1 text-[13px]">The shell, auth, and Discover (live data) are wired up.</p>
    </div>
  );
}

export function MyPlans() {
  return (<><Header title={t("My Plans")} /><Building name="My Plans" /></>);
}
export function CreatePlan() {
  const nav = useNavigate();
  return (
    <div className="px-5 pt-3">
      <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
      <Building name="Create a table" />
    </div>
  );
}
export function Messages() {
  return (<><Header title={t("Messages")} /><Building name="Messages" /></>);
}

export function RestaurantBoard() {
  const { id } = useParams();
  const nav = useNavigate();
  return (
    <div className="px-5 pt-3">
      <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
      <Building name={`Restaurant board (${id?.slice(0, 8)}…)`} />
    </div>
  );
}
export function PlanDetail() {
  const { id } = useParams();
  const nav = useNavigate();
  return (
    <div className="px-5 pt-3">
      <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
      <Building name={`Plan detail (${id?.slice(0, 8)}…)`} />
    </div>
  );
}

export function Profile() {
  const { user, signOut } = useAuth();
  const lang = currentLang();
  return (
    <div className="px-5 pb-8 pt-3">
      <h1 className="font-sans text-[40px] text-clayDeep">{t("Profile")}</h1>
      <div className="mt-6 rounded-card bg-shell p-4">
        <div className="text-[18px] font-medium text-ink">{user?.display_name ?? "—"}</div>
        <div className="text-[13px] text-inkMuted">{user?.email || "guest"}</div>
      </div>

      <div className="mt-6 text-[13px] font-semibold uppercase tracking-wide text-inkMuted">Language</div>
      <div className="mt-2 flex gap-2">
        {(["en", "zh-Hans", "zh-Hant"] as const).map((l) => (
          <button
            key={l}
            onClick={() => setLang(l)}
            className={`rounded-full px-3 py-1.5 text-[13px] font-semibold ${
              lang === l ? "bg-clay text-cream" : "bg-shell text-ink"
            }`}
          >
            {l === "en" ? "English" : l === "zh-Hans" ? "简体" : "繁體"}
          </button>
        ))}
      </div>

      <button className="pin-btn-secondary mt-8" onClick={signOut}>
        Sign out
      </button>

      <p className="mt-6 text-center text-[12px] text-inkMuted">Full profile, credits & settings — next phase.</p>
    </div>
  );
}
