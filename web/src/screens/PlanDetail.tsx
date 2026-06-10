// Mirrors PlanDetailView.swift: summary, members (with organiser crown + kick),
// organiser actions (lock time / confirm attendance / add to calendar), realtime
// chat + polls, join/leave, share, report/block.
import { useEffect, useRef, useState, type ReactNode } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchPlan,
  fetchRestaurants,
  fetchMessages,
  fetchUsers,
  sendMessage,
  joinPlan,
  leavePlan,
  removeMember,
  deletePlan,
  listenToMessages,
  listenToPlan,
  setPlanScheduledTime,
  confirmAttendance,
  fetchPolls,
  fetchVotes,
  createPoll,
  castVote,
  listenToPolls,
} from "@/services/db";
import {
  restaurantName,
  needsMorePeople,
  type ChatMessage,
  type Plan,
  type AppUser,
  type Restaurant,
  type Poll,
  type PollVote,
} from "@/types";
import { t, systemMessageText, formatDateTime } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { useUnread } from "@/unread/UnreadContext";
import { trackJoinClick, trackGuestJoinSuccess } from "@/lib/analytics";
import { Chip, Spinner } from "@/components/ui";

function timeLabel(p: Plan) {
  if (p.time_type === "asap") return t("ASAP");
  if (p.time_type === "flexible")
    return `${t(p.flex_day === "weekend" ? "Weekend" : "Weekday")} ${t(p.flex_meal === "dinner" ? "Dinner" : "Lunch")}`;
  return formatDateTime(p.scheduled_at);
}

function genderLabel(g: Plan["gender_preference"]): string {
  return g === "female" ? t("Female only") : g === "male" ? t("Male only") : t("Open to any");
}

/** Cross-platform "add to calendar": open a Google Calendar template (mirrors the
 *  iOS EventKit add — same event, web-native mechanism). */
function googleCalUrl(plan: Plan, r: Restaurant | undefined): string {
  const start = new Date(plan.scheduled_at);
  const end = new Date(start.getTime() + 2 * 3600_000);
  const fmt = (d: Date) => d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const title = `PinTable: ${r ? restaurantName(r) : plan.restaurant_name}`;
  const params = new URLSearchParams({
    action: "TEMPLATE",
    text: title,
    dates: `${fmt(start)}/${fmt(end)}`,
    details: plan.notes || "",
    location: r?.address || "",
  });
  return `https://calendar.google.com/calendar/render?${params.toString()}`;
}

export function PlanDetail() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const loc = useLocation();
  const qc = useQueryClient();
  const { user, reportPlan, blockUser, hasReported, hasBlocked } = useAuth();
  const { markRead } = useUnread();

  // A stranger who opened a shared link has no in-app history to go "back" to —
  // react-router stamps history.state.idx (0 = first entry) and marks the first
  // location key "default". In that case "back" would leave the site entirely,
  // stranding them on the plan with no tab bar, so send them into Discover where
  // they can browse the app as a guest.
  const goBack = () => {
    const idx = (window.history.state as { idx?: number } | null)?.idx ?? 0;
    if (idx > 0 && loc.key !== "default") nav(-1);
    else nav("/discover");
  };

  const planQ = useQuery({ queryKey: ["plan", id], queryFn: () => fetchPlan(id), enabled: !!id });
  const plan = planQ.data ?? null;
  const restaurantsQ = useQuery({ queryKey: ["restaurants"], queryFn: fetchRestaurants, staleTime: 5 * 60_000 });
  const cachedRestaurant = (restaurantsQ.data ?? []).find((r) => r.id === plan?.restaurant_id);

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [members, setMembers] = useState<AppUser[]>([]);
  const [polls, setPolls] = useState<Poll[]>([]);
  const [votes, setVotes] = useState<PollVote[]>([]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [showNamePrompt, setShowNamePrompt] = useState(false);
  const [guestName, setGuestName] = useState("");
  const [sheet, setSheet] = useState<null | "poll" | "attendance" | "lock" | "report">(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const lastSeenAtMount = useRef<string>(
    localStorage.getItem(`unread.lastSeen.plan-${id}`) ?? "1970-01-01T00:00:00.000Z",
  );

  // Chat + poll initial load and realtime.
  useEffect(() => {
    if (!id) return;
    fetchMessages(id).then(setMessages).catch(() => {});
    const reloadPolls = () => {
      fetchPolls(id).then(setPolls).catch(() => {});
      fetchVotes(id).then(setVotes).catch(() => {});
    };
    reloadPolls();
    const offMsg = listenToMessages(id, (m) => setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m])));
    const offPlan = listenToPlan(id, () => qc.invalidateQueries({ queryKey: ["plan", id] }));
    const offPolls = listenToPolls(id, reloadPolls);
    return () => { offMsg(); offPlan(); offPolls(); };
  }, [id, qc]);

  useEffect(() => {
    if (plan) fetchUsers(plan.member_ids).then(setMembers).catch(() => {});
  }, [plan?.member_ids?.join(",")]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages.length, polls.length]);

  useEffect(() => {
    if (id) markRead(`plan-${id}`);
  }, [id, messages.length, markRead]);

  if (planQ.isLoading) return <Spinner />;
  if (!plan) return <div className="p-6 text-inkMuted">Not found.</div>;

  const nameById: Record<string, string> = Object.fromEntries(members.map((m) => [m.id, m.display_name]));
  const renderSystem = (m: ChatMessage): string => {
    const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const args = (m.system_args ?? []).map((a) => nameById[a] ?? a);
    if (args.some((a) => UUID.test(a))) return m.text || systemMessageText(m.system_kind, args);
    return systemMessageText(m.system_kind, args);
  };

  const isMember = !!user && plan.member_ids.includes(user.id);
  const isOrganiser = !!user && plan.creator_id === user.id;
  const need = needsMorePeople(plan);
  const confirmed = !!plan.attendance_confirmed_at;
  const now = Date.now();
  const canLockTime = isOrganiser && !confirmed && need === 0 && plan.time_type !== "scheduled";
  const canConfirmAttendance =
    isOrganiser && !confirmed && need === 0 && plan.time_type === "scheduled" && new Date(plan.scheduled_at).getTime() <= now;
  const canAddToCalendar = plan.time_type === "scheduled" && !confirmed;

  // Merge chat + polls into one time-ordered stream (mirrors ChatStreamItem).
  type Item = { kind: "msg"; ts: string; m: ChatMessage } | { kind: "poll"; ts: string; p: Poll };
  const stream: Item[] = [
    ...messages.map((m): Item => ({ kind: "msg", ts: m.timestamp, m })),
    ...polls.map((p): Item => ({ kind: "poll", ts: p.created_at ?? "", p })),
  ].sort((a, b) => a.ts.localeCompare(b.ts));

  async function cancelPlan() {
    if (!plan || !window.confirm(t("Cancel this plan?"))) return;
    setBusy(true);
    try {
      await deletePlan(plan.id);
      nav("/plans", { replace: true });
    } finally {
      setBusy(false);
    }
  }

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

  async function kick(target: AppUser) {
    if (!user || !plan) return;
    if (!window.confirm(t("Remove %@ from the group?", target.display_name))) return;
    setBusy(true);
    try {
      await removeMember(plan, target.id, target.display_name, user.display_name);
      await qc.invalidateQueries({ queryKey: ["plan", id] });
    } finally {
      setBusy(false);
    }
  }

  async function vote(pollId: string, optionIndex: number) {
    if (!user || !isMember) return;
    await castVote({ poll_id: pollId, user_id: user.id, option_index: optionIndex });
    fetchVotes(id).then(setVotes).catch(() => {});
  }

  async function send() {
    const text = draft.trim();
    if (!text || !user) return;
    setDraft("");
    await sendMessage(id, user, text);
  }

  async function share() {
    const url = `https://pintable-london.web.app/plan/${plan!.id}`;
    const msg = t("Come share this dining plan with me on PinTable.");
    if (navigator.share) {
      try {
        await navigator.share({ title: "PinTable", text: msg, url });
        return;
      } catch (e) {
        if (e instanceof DOMException && e.name === "AbortError") return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      alert(t("Link copied"));
    } catch {
      window.prompt(t("Copy this link"), url);
    }
  }

  return (
    <div className="flex h-full flex-col">
      {/* Top bar */}
      <div className="flex items-center gap-2 border-b border-fog bg-shell px-4 py-3">
        <button onClick={goBack} className="text-[22px] text-ink">‹</button>
        <span className="flex-1 truncate text-center font-medium text-ink">
          {cachedRestaurant ? restaurantName(cachedRestaurant) : plan.restaurant_name}
        </span>
        <button onClick={share} className="text-clay" aria-label={t("Share")}>
          <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 16V4" />
            <path d="m8 8 4-4 4 4" />
            <path d="M20 14v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-5" />
          </svg>
        </button>
        <button onClick={() => setSheet("report")} className="text-ink" aria-label={t("Report or block")}>
          <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
            <circle cx="12" cy="5" r="1.4" /><circle cx="12" cy="12" r="1.4" /><circle cx="12" cy="19" r="1.4" />
          </svg>
        </button>
      </div>

      {/* Scrollable content */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto px-5 py-4">
        {/* Summary */}
        <div className="rounded-card bg-shell p-4">
          <div className="flex items-center">
            <span className="font-medium text-ink">🕐 {timeLabel(plan)}</span>
            <span className="ml-auto text-[13px] font-medium text-inkMuted tabular-nums">
              👥 {t("%lld/%lld joined", plan.current_people, plan.needed_people)}
            </span>
          </div>
          <div className="mt-2 flex flex-wrap items-center gap-1.5">
            {need > 0 ? <Chip text={t("Need %lld more", need)} /> : <Chip text={t("Group is full")} tint="sage" />}
            {plan.gender_preference !== "any" && <Chip text={genderLabel(plan.gender_preference)} tint="lavender" />}
            {confirmed && <Chip text={t("Confirmed")} tint="sage" />}
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

        {/* Organiser actions */}
        {(canLockTime || canConfirmAttendance || canAddToCalendar) && (
          <div className="mt-3 flex flex-col gap-2">
            {canLockTime && (
              <button className="pin-btn-primary" onClick={() => setSheet("lock")}>
                ⏰ {t("Lock in the time")}
              </button>
            )}
            {canConfirmAttendance && (
              <button className="pin-btn-primary" onClick={() => setSheet("attendance")}>
                ✅ {t("Confirm attendance")}
              </button>
            )}
            {canAddToCalendar && (
              <a
                href={googleCalUrl(plan, cachedRestaurant)}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center gap-1.5 rounded-full bg-clay/[0.12] py-2.5 text-[14px] font-semibold text-clayDeep"
              >
                📅 {t("Add to calendar")}
              </a>
            )}
          </div>
        )}

        {/* Members */}
        <div className="mt-4">
          <div className="text-[11px] font-medium uppercase tracking-wide text-sunDeep">⛵ {t("My mates")}</div>
          <div className="mt-2 flex flex-wrap gap-2">
            {members.map((m) => {
              const memberIsOrganiser = m.id === plan.creator_id;
              return (
                <div key={m.id} className="flex items-center gap-1 rounded-full bg-shell px-2.5 py-1">
                  <button onClick={() => nav(`/user/${m.id}`)} className="flex items-center gap-1.5 active:opacity-70">
                    <Avatar user={m} />
                    <span className="text-[13px] text-ink">{m.display_name}</span>
                    {memberIsOrganiser && <span title={t("Organiser")}>👑</span>}
                  </button>
                  {isOrganiser && !memberIsOrganiser && (
                    <button onClick={() => kick(m)} disabled={busy} className="ml-0.5 text-clayDeep disabled:opacity-40" aria-label={t("Remove")}>
                      <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round">
                        <circle cx="12" cy="12" r="9" /><path d="M8 12h8" />
                      </svg>
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Chat + polls */}
        <div className="mt-5 space-y-2">
          {stream.map((it, i) => {
            const prevTs = i > 0 ? stream[i - 1].ts : "";
            const isFirstUnread = it.ts > lastSeenAtMount.current && (i === 0 || prevTs <= lastSeenAtMount.current);
            return (
              <div key={it.kind === "msg" ? it.m.id : `poll-${it.p.id}`}>
                {isFirstUnread && (
                  <div className="my-2 flex items-center gap-2">
                    <div className="flex-1 border-t border-clay/40" />
                    <span className="text-[11px] font-semibold text-clay">{t("New messages")}</span>
                    <div className="flex-1 border-t border-clay/40" />
                  </div>
                )}
                {it.kind === "poll" ? (
                  <PollCard
                    poll={it.p}
                    votes={votes.filter((v) => v.poll_id === it.p.id)}
                    currentUid={user?.id ?? ""}
                    canVote={isMember}
                    onVote={(idx) => vote(it.p.id, idx)}
                  />
                ) : it.m.is_system ? (
                  <div className="text-center text-[12px] text-inkMuted">{renderSystem(it.m)}</div>
                ) : (
                  <Bubble m={it.m} mine={it.m.sender_id === user?.id} />
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
              onKeyDown={(e) => e.key === "Enter" && guestName.trim().length >= 1 && document.getElementById("guest-join-btn")?.click()}
              autoFocus
            />
            <div className="mt-2 flex gap-2">
              <button
                id="guest-join-btn"
                className="flex-1 rounded-full bg-clay py-2.5 text-[14px] font-semibold text-cream disabled:opacity-40"
                disabled={guestName.trim().length < 1 || busy}
                onClick={async () => {
                  if (!user || guestName.trim().length < 1) return;
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
                {t("Cancel")}
              </button>
            </div>
          </div>
        )}
        {isMember ? (
          <div className="flex items-center gap-2">
            <button
              onClick={() => setSheet("poll")}
              className="text-clay"
              aria-label={t("New poll")}
            >
              <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                <path d="M3 3v18h18" /><rect x="7" y="10" width="3" height="7" /><rect x="12" y="6" width="3" height="11" /><rect x="17" y="13" width="3" height="4" />
              </svg>
            </button>
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
        ) : showNamePrompt ? null : (
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
        {isMember && isOrganiser && (
          <div className="mt-2 flex gap-2">
            <button
              className="flex flex-1 items-center justify-center gap-1.5 rounded-full bg-clay/[0.12] py-2.5 text-[14px] font-semibold text-clayDeep"
              onClick={() => nav(`/create?plan=${id}`)}
            >
              <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 20h9" />
                <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4Z" />
              </svg>
              {t("Edit")}
            </button>
            <button
              className="flex-1 rounded-full bg-clay/[0.12] py-2.5 text-[14px] font-semibold text-clayDeep disabled:opacity-50"
              disabled={busy}
              onClick={cancelPlan}
            >
              {t("Cancel plan")}
            </button>
          </div>
        )}
        {isMember && !isOrganiser && (
          <button
            className="mt-2 flex w-full items-center justify-center gap-1.5 rounded-full bg-clay/[0.12] py-2.5 text-[14px] font-semibold text-clayDeep disabled:opacity-50"
            disabled={busy}
            onClick={toggleMembership}
          >
            <svg width={15} height={15} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
              <polyline points="9 14 4 9 9 4" />
              <path d="M20 20v-7a4 4 0 0 0-4-4H4" />
            </svg>
            {t("Leave")}
          </button>
        )}
      </div>

      {/* Sheets */}
      {sheet === "poll" && user && (
        <CreatePollSheet
          planId={id}
          creator={user}
          onClose={() => setSheet(null)}
          onCreated={() => { fetchPolls(id).then(setPolls).catch(() => {}); setSheet(null); }}
        />
      )}
      {sheet === "attendance" && (
        <AttendanceSheet
          members={members}
          organiserId={plan.creator_id}
          onClose={() => setSheet(null)}
          onConfirm={async (ids) => {
            await confirmAttendance(plan.id, ids);
            await qc.invalidateQueries({ queryKey: ["plan", id] });
            setSheet(null);
          }}
        />
      )}
      {sheet === "lock" && (
        <LockTimeSheet
          initial={new Date(Math.max(Date.now() + 1800_000, new Date(plan.scheduled_at).getTime() || 0))}
          onClose={() => setSheet(null)}
          onLock={async (d) => {
            await setPlanScheduledTime(plan.id, d);
            await qc.invalidateQueries({ queryKey: ["plan", id] });
            setSheet(null);
          }}
        />
      )}
      {sheet === "report" && (
        <ReportBlockSheet
          alreadyReported={hasReported(plan.id)}
          alreadyBlocked={hasBlocked(plan.creator_id)}
          canBlock={!!user && user.id !== plan.creator_id}
          onClose={() => setSheet(null)}
          onReport={async () => { await reportPlan(plan.id); setSheet(null); }}
          onBlock={async () => { await blockUser(plan.creator_id); setSheet(null); }}
        />
      )}
    </div>
  );
}

function Avatar({ user }: { user: AppUser }) {
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

// ----- Poll card (mirrors PollCardView.swift) -----

function PollCard({
  poll, votes, currentUid, canVote, onVote,
}: { poll: Poll; votes: PollVote[]; currentUid: string; canVote: boolean; onVote: (i: number) => void }) {
  const total = votes.length;
  const myVote = votes.find((v) => v.user_id === currentUid)?.option_index;
  const count = (i: number) => votes.filter((v) => v.option_index === i).length;
  return (
    <div className="rounded-2xl bg-shell p-3.5">
      <div className="flex items-center gap-1.5">
        <span className="text-clay">📊</span>
        <span className="flex-1 text-[14px] font-medium text-ink">{poll.question}</span>
        <span className="text-[11px] text-inkMuted tabular-nums">{t("%lld votes", total)}</span>
      </div>
      <div className="mt-2 space-y-1.5">
        {poll.options.map((opt, i) => {
          const n = count(i);
          const mine = myVote === i;
          const pct = total > 0 ? (n / total) * 100 : 0;
          return (
            <button
              key={i}
              disabled={!canVote}
              onClick={() => onVote(i)}
              className={`relative flex w-full items-center overflow-hidden rounded-lg border px-2.5 py-2 text-left disabled:cursor-default ${mine ? "border-clay/30" : "border-transparent"}`}
            >
              <div className={`absolute inset-y-0 left-0 ${mine ? "bg-clay/20" : "bg-cream"}`} style={{ width: `${Math.max(pct, 8)}%` }} />
              <span className="relative flex flex-1 items-center gap-1.5 text-[13px] text-ink">
                {mine && <span className="text-clay">✓</span>}
                {opt}
              </span>
              <span className="relative text-[12px] text-inkMuted tabular-nums">{n}</span>
            </button>
          );
        })}
      </div>
      <div className="mt-1.5 text-[11px] text-inkMuted">{t("by %@", poll.creator_name)}</div>
    </div>
  );
}

// ----- Sheets -----

function SheetShell({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/30" onClick={onClose}>
      <div className="w-full max-w-[480px] rounded-t-3xl bg-cream p-5 pb-8" onClick={(e) => e.stopPropagation()}>
        <div className="mb-4 flex items-center">
          <button onClick={onClose} className="text-[14px] font-semibold text-ink">{t("Cancel")}</button>
          <span className="flex-1 text-center text-[15px] font-medium text-ink">{title}</span>
          <span className="w-10" />
        </div>
        {children}
      </div>
    </div>
  );
}

function CreatePollSheet({
  planId, creator, onClose, onCreated,
}: { planId: string; creator: AppUser; onClose: () => void; onCreated: () => void }) {
  const [question, setQuestion] = useState("");
  const [options, setOptions] = useState<string[]>(["", ""]);
  const [busy, setBusy] = useState(false);
  const canPost = question.trim().length > 0 && options.filter((o) => o.trim()).length >= 2;
  return (
    <SheetShell title={t("New poll")} onClose={onClose}>
      <label className="text-[11px] font-semibold uppercase tracking-wide text-inkMuted">{t("Question")}</label>
      <input className="pin-field mt-1.5" placeholder={t("Where should we eat?")} value={question} onChange={(e) => setQuestion(e.target.value)} autoFocus />
      <label className="mt-4 block text-[11px] font-semibold uppercase tracking-wide text-inkMuted">{t("Options")}</label>
      <div className="mt-1.5 space-y-2">
        {options.map((o, i) => (
          <input
            key={i}
            className="pin-field"
            placeholder={t("Option %lld", i + 1)}
            value={o}
            onChange={(e) => setOptions((prev) => prev.map((x, j) => (j === i ? e.target.value : x)))}
          />
        ))}
        {options.length < 6 && (
          <button className="text-[14px] font-semibold text-clay" onClick={() => setOptions((p) => [...p, ""])}>
            ＋ {t("Add option")}
          </button>
        )}
      </div>
      <button
        className="pin-btn-primary mt-5 disabled:opacity-40"
        disabled={!canPost || busy}
        onClick={async () => {
          setBusy(true);
          const opts = options.map((o) => o.trim()).filter(Boolean);
          await createPoll({
            id: crypto.randomUUID(),
            plan_id: planId,
            creator_id: creator.id,
            creator_name: creator.display_name,
            question: question.trim(),
            options: opts,
            created_at: new Date().toISOString(),
          });
          onCreated();
        }}
      >
        {t("Post")}
      </button>
    </SheetShell>
  );
}

function AttendanceSheet({
  members, organiserId, onClose, onConfirm,
}: { members: AppUser[]; organiserId: string; onClose: () => void; onConfirm: (ids: string[]) => Promise<void> }) {
  const [attended, setAttended] = useState<Set<string>>(() => new Set(members.map((m) => m.id)));
  const [busy, setBusy] = useState(false);
  const toggle = (id: string) =>
    setAttended((prev) => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  return (
    <SheetShell title={t("Confirm attendance")} onClose={onClose}>
      <div className="text-[15px] font-medium text-ink">{t("Who actually showed up?")}</div>
      <p className="mt-1 text-[13px] text-inkMuted">{t("Tap to toggle who attended. We use this to keep credit scores honest.")}</p>
      <div className="mt-3 divide-y divide-fog rounded-2xl bg-shell">
        {members.map((m) => {
          const on = attended.has(m.id);
          return (
            <button key={m.id} onClick={() => toggle(m.id)} className="flex w-full items-center gap-3 px-3.5 py-3 text-left">
              <Avatar user={m} />
              <div className="flex-1">
                <div className="text-[14px] text-ink">{m.display_name}</div>
                {m.id === organiserId && <div className="text-[11px] text-clayDeep">{t("Organiser")}</div>}
              </div>
              <span className={on ? "text-clay" : "text-inkMuted/40"}>{on ? "☑︎" : "☐"}</span>
            </button>
          );
        })}
      </div>
      <button
        className="pin-btn-primary mt-5 disabled:opacity-50"
        disabled={busy}
        onClick={async () => { setBusy(true); try { await onConfirm([...attended]); } finally { setBusy(false); } }}
      >
        {t("Confirm")}
      </button>
    </SheetShell>
  );
}

function LockTimeSheet({
  initial, onClose, onLock,
}: { initial: Date; onClose: () => void; onLock: (d: Date) => Promise<void> }) {
  const [value, setValue] = useState(() => {
    const d = initial;
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  });
  const [busy, setBusy] = useState(false);
  return (
    <SheetShell title={t("Lock in the meet-up time")} onClose={onClose}>
      <input type="datetime-local" className="pin-field" value={value} onChange={(e) => setValue(e.target.value)} />
      <button
        className="pin-btn-primary mt-5 disabled:opacity-50"
        disabled={busy || !value}
        onClick={async () => { setBusy(true); try { await onLock(new Date(value)); } finally { setBusy(false); } }}
      >
        {t("Lock")}
      </button>
    </SheetShell>
  );
}

function ReportBlockSheet({
  alreadyReported, alreadyBlocked, canBlock, onClose, onReport, onBlock,
}: {
  alreadyReported: boolean; alreadyBlocked: boolean; canBlock: boolean;
  onClose: () => void; onReport: () => Promise<void>; onBlock: () => Promise<void>;
}) {
  return (
    <SheetShell title={t("Report or block")} onClose={onClose}>
      <div className="overflow-hidden rounded-2xl bg-shell">
        <button
          disabled={alreadyReported}
          onClick={() => { if (window.confirm(t("Report this plan") + "?")) onReport(); }}
          className="flex w-full items-center gap-3 px-4 py-3.5 text-left disabled:opacity-50"
        >
          <span className="text-clayDeep">🚩</span>
          <span className="text-[14px] text-ink">{alreadyReported ? t("Plan already reported") : t("Report this plan")}</span>
        </button>
        <div className="h-px bg-fog" />
        <button
          disabled={alreadyBlocked || !canBlock}
          onClick={() => { if (window.confirm(t("Block this user") + "?")) onBlock(); }}
          className="flex w-full items-center gap-3 px-4 py-3.5 text-left disabled:opacity-50"
        >
          <span className="text-clay">🚫</span>
          <span className="text-[14px] text-ink">{alreadyBlocked ? t("User already blocked") : t("Block this user")}</span>
        </button>
      </div>
      <p className="mt-3 px-1 text-[12px] text-inkMuted">
        {t("Reported content is reviewed by moderators. Repeated misuse may result in removal from PinTable.")}
      </p>
    </SheetShell>
  );
}
