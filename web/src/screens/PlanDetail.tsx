// Mirrors PlanDetailView.swift (core): summary, members, realtime chat,
// join/leave, share. Polls / attendance / lock-time / calendar come next.
import { useEffect, useRef, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchPlan,
  fetchRestaurants,
  fetchMessages,
  fetchUsers,
  sendMessage,
  joinPlan,
  leavePlan,
  listenToMessages,
  listenToPlan,
} from "@/services/db";
import { restaurantName, needsMorePeople, type ChatMessage, type Plan, type AppUser, type Restaurant } from "@/types";
import { t, systemMessageText } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { useUnread } from "@/unread/UnreadContext";
import { trackJoinClick, trackGuestJoinSuccess } from "@/lib/analytics";
import { Chip, Spinner } from "@/components/ui";

function timeLabel(p: Plan) {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible")
    return `${t(p.flex_day === "weekend" ? "Weekend" : "Weekday")} ${t(p.flex_meal === "dinner" ? "Dinner" : "Lunch")}`;
  return new Date(p.scheduled_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

export function PlanDetail() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const qc = useQueryClient();
  const { user } = useAuth();
  const { markRead } = useUnread();

  const planQ = useQuery({ queryKey: ["plan", id], queryFn: () => fetchPlan(id), enabled: !!id });
  const plan = planQ.data ?? null;
  // Ensure the restaurant list is in cache so we can look up the localized name.
  const restaurantsQ = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants, staleTime: 5 * 60_000 });
  const cachedRestaurant = (restaurantsQ.data ?? []).find((r) => r.id === plan?.restaurant_id);

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [members, setMembers] = useState<AppUser[]>([]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [showNamePrompt, setShowNamePrompt] = useState(false);
  const [guestName, setGuestName] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);
  // Snapshot "last seen" at mount time so the divider stays put while reading.
  const lastSeenAtMount = useRef<string>(
    localStorage.getItem(`unread.lastSeen.plan-${id}`) ?? "1970-01-01T00:00:00.000Z"
  );

  // Initial chat load + realtime subscriptions.
  useEffect(() => {
    if (!id) return;
    fetchMessages(id).then(setMessages).catch(() => {});
    const offMsg = listenToMessages(id, (m) => setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m])));
    const offPlan = listenToPlan(id, () => qc.invalidateQueries({ queryKey: ["plan", id] }));
    return () => { offMsg(); offPlan(); };
  }, [id, qc]);

  useEffect(() => {
    if (plan) fetchUsers(plan.member_ids).then(setMembers).catch(() => {});
  }, [plan?.member_ids?.join(",")]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages.length]);

  // Mark this plan's chat + actions as seen while it's open.
  useEffect(() => {
    if (id) markRead(`plan-${id}`);
  }, [id, messages.length, markRead]);

  if (planQ.isLoading) return <Spinner />;
  if (!plan) return <div className="p-6 text-inkMuted">Not found.</div>;

  // System lines from iOS carry the member's UUID in system_args but a real
  // sentence in `text`; web rebuilds (for localization) from args. Resolve any
  // known member UUID to their name; if an arg is still an unresolved UUID,
  // fall back to the stored sentence so we never show a raw id.
  const nameById: Record<string, string> = Object.fromEntries(members.map((m) => [m.id, m.display_name]));
  const renderSystem = (m: ChatMessage): string => {
    const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const args = (m.system_args ?? []).map((a) => nameById[a] ?? a);
    if (args.some((a) => UUID.test(a))) return m.text || systemMessageText(m.system_kind, args);
    return systemMessageText(m.system_kind, args);
  };

  const isMember = !!user && plan.member_ids.includes(user.id);
  const need = needsMorePeople(plan);

  async function toggleMembership() {
    if (!user || !plan) return;
    setBusy(true);
    try {
      if (isMember) await leavePlan(plan, user.id, user.display_name);
      else await joinPlan(plan, user.id, user.display_name);
      await qc.invalidateQueries({ queryKey: ["plan", id] });
    } finally {
      setBusy(false);
    }
  }

  async function send() {
    const text = draft.trim();
    if (!text || !user) return;
    setDraft("");
    await sendMessage(id, user, text);
  }

  function share() {
    const url = `https://phoebe725.github.io/DealMates/plan.html?plan=${plan!.id}`;
    if (navigator.share) navigator.share({ title: "Join my plan on PinTable", url }).catch(() => {});
    else { navigator.clipboard?.writeText(url); alert("Link copied"); }
  }

  return (
    <div className="flex h-full flex-col">
      {/* Top bar */}
      <div className="flex items-center gap-2 border-b border-fog bg-shell px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <span className="flex-1 truncate text-center font-medium text-ink">
          {cachedRestaurant ? restaurantName(cachedRestaurant) : plan.restaurant_name}
        </span>
        <button onClick={share} className="text-[18px] text-clay" aria-label={t("Share")}>⤴</button>
      </div>

      {/* Scrollable content */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-5 py-4">
        {/* Summary */}
        <div className="rounded-card bg-shell p-4">
          <div className="flex items-center">
            <span className="font-medium text-ink">🕐 {timeLabel(plan)}</span>
            <span className="ml-auto">
              {need > 0 ? <Chip text={t("Need %lld more", need)} /> : <Chip text={t("Group is full")} tint="sage" />}
            </span>
          </div>
          {plan.notes && <p className="mt-2 text-[13px] text-inkMuted">{plan.notes}</p>}
          {plan.event_code && (
            <div className="mt-3 flex items-center justify-between rounded-xl bg-cream px-3 py-2">
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-wide text-inkMuted">Event code</div>
                <div className="font-mono text-[20px] font-bold tracking-widest text-clay">{plan.event_code}</div>
              </div>
              <button
                onClick={() => navigator.clipboard?.writeText(plan.event_code!)}
                className="rounded-full bg-clay/15 px-3 py-1 text-[12px] font-semibold text-clay"
              >
                Copy
              </button>
            </div>
          )}
          {plan.created_at && (
            <p className="mt-2 text-[11px] text-inkMuted">
              {t("Created %@", new Date(plan.created_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }))}
            </p>
          )}
        </div>

        {/* Members */}
        <div className="mt-4">
          <div className="text-[11px] font-medium uppercase tracking-wide text-sunDeep">⛵ {t("My mates")}</div>
          <div className="mt-2 flex flex-wrap gap-2">
            {members.map((m) => (
              <button
                key={m.id}
                onClick={() => nav(`/user/${m.id}`)}
                className="flex items-center gap-1.5 rounded-full bg-shell px-2.5 py-1 active:bg-fog"
              >
                <Avatar user={m} />
                <span className="text-[13px] text-ink">{m.display_name}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Chat */}
        <div className="mt-5 space-y-2">
          {messages.map((m, i) => {
            const isFirstUnread =
              m.timestamp > lastSeenAtMount.current &&
              (i === 0 || messages[i - 1].timestamp <= lastSeenAtMount.current);
            return (
              <div key={m.id}>
                {isFirstUnread && (
                  <div className="my-2 flex items-center gap-2">
                    <div className="flex-1 border-t border-clay/40" />
                    <span className="text-[11px] font-semibold text-clay">{t("New messages")}</span>
                    <div className="flex-1 border-t border-clay/40" />
                  </div>
                )}
                {m.is_system ? (
                  <div className="text-center text-[12px] text-inkMuted">{renderSystem(m)}</div>
                ) : (
                  <Bubble m={m} mine={m.sender_id === user?.id} />
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Join/leave + composer */}
      <div className="border-t border-fog bg-cream px-4 py-3">
        {showNamePrompt && (
          <div className="mb-3 rounded-card bg-shell p-3">
            <div className="text-[14px] font-medium text-ink">{t("What should we call you?")}</div>
            <p className="mt-0.5 text-[12px] text-inkMuted">{t("No account needed — just a name.")}</p>
            <input
              className="pin-field mt-2"
              placeholder={t("Your name")}
              value={guestName}
              onChange={(e) => setGuestName(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && guestName.trim().length >= 2 && document.getElementById("guest-join-btn")?.click()}
              autoFocus
            />
            <div className="mt-2 flex gap-2">
              <button
                id="guest-join-btn"
                className="flex-1 rounded-full bg-clay py-2.5 text-[14px] font-semibold text-cream disabled:opacity-40"
                disabled={guestName.trim().length < 2 || busy}
                onClick={async () => {
                  if (!user || guestName.trim().length < 2) return;
                  const { updateProfile } = await import("@/services/db");
                  await updateProfile(user.id, { display_name: guestName.trim() });
                  user.display_name = guestName.trim();
                  setShowNamePrompt(false);
                  trackGuestJoinSuccess(id, plan.restaurant_id);
                  toggleMembership();
                }}
              >
                {t("Join as guest")}
              </button>
              <button
                className="rounded-full bg-shell px-4 py-2.5 text-[14px] font-semibold text-inkMuted"
                onClick={() => setShowNamePrompt(false)}
              >
                Cancel
              </button>
            </div>
          </div>
        )}
        {isMember ? (
          <div className="flex items-center gap-2">
            <input
              className="pin-field flex-1"
              placeholder={t("Message…")}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
            />
            <button className="rounded-full bg-clay px-4 py-2.5 font-semibold text-cream" onClick={send}>
              {t("Send")}
            </button>
          </div>
        ) : (
          <button
            className="pin-btn-primary"
            disabled={busy || need === 0}
            onClick={() => {
              trackJoinClick(id, plan.restaurant_id);
              if (user?.is_anonymous) setShowNamePrompt(true);
              else toggleMembership();
            }}
          >
            {need === 0 ? t("Group is full") : t("Join this plan")}
          </button>
        )}
        {isMember && (
          <button className="mt-2 w-full text-center text-[13px] text-inkMuted" disabled={busy} onClick={toggleMembership}>
            {t("Leave")}
          </button>
        )}
      </div>
    </div>
  );
}

function Avatar({ user }: { user: AppUser }) {
  // Default to the app logo (puffin) when there's no photo.
  return <img src={user.avatar_url || "/icon.png"} alt="" className="h-5 w-5 rounded-full object-cover" />;
}

function Bubble({ m, mine }: { m: ChatMessage; mine: boolean }) {
  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div className={`max-w-[78%] rounded-2xl px-3 py-2 text-[14px] ${mine ? "bg-clay text-cream" : "bg-shell text-ink"}`}>
        {!mine && <div className="text-[11px] font-medium text-inkMuted">{m.sender_name}</div>}
        {m.text}
      </div>
    </div>
  );
}
