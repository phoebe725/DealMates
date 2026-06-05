// Mirrors MessagesView + MessagesListViewModel: one list combining DM
// conversations and the user's plan group-chats, newest activity first.
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchConversations, fetchMyPlans, fetchLatestMessages } from "@/services/db";
import type { DMConversation, Plan } from "@/types";
import { t, systemMessageText } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { useUnread } from "@/unread/UnreadContext";
import { usePullToRefresh } from "@/hooks/usePullToRefresh";
import { EmptyState, Segmented, Spinner } from "@/components/ui";

type Filter = "all" | "dm" | "plan";

type Item =
  | { kind: "dm"; id: string; title: string; avatar: string | null; preview: string; ts: string; fromSelf: boolean }
  | { kind: "plan"; id: string; title: string; avatar: string | null; preview: string; subtitle: string; ts: string; fromSelf: boolean };

export function Messages() {
  const nav = useNavigate();
  const { user } = useAuth();
  const { unreadDMCount, isUnread } = useUnread();
  const [filter, setFilter] = useState<Filter>("all");
  const { ref: pullRef, refreshing } = usePullToRefresh(async () => { await q.refetch(); });

  const q = useQuery({
    queryKey: ["messagesList", user?.id],
    enabled: !!user,
    queryFn: async () => {
      const [dms, plans] = await Promise.all([
        fetchConversations(user!.id),
        fetchMyPlans(user!.id),
      ]);
      const latest = await fetchLatestMessages(plans.map((p) => p.id));
      return { dms, plans, latest };
    },
  });

  const items = useMemo<Item[]>(() => {
    if (!q.data) return [];
    const out: Item[] = [];
    for (const d of q.data.dms as DMConversation[]) {
      out.push({ kind: "dm", id: d.otherUserId, title: d.otherUserName, avatar: d.otherUserAvatarURL, preview: d.lastMessage, ts: d.lastTimestamp, fromSelf: d.lastSenderId === user!.id });
    }
    for (const p of q.data.plans as Plan[]) {
      const last = q.data.latest[p.id];
      const preview = last
        ? last.is_system
          ? systemMessageText(last.system_kind, last.system_args)
          : last.text
        : t("No messages yet");
      out.push({
        kind: "plan",
        id: p.id,
        title: p.restaurant_name,
        avatar: p.creator_avatar_url,
        preview,
        subtitle: t("Group · %lld/%lld", p.current_people, p.needed_people),
        ts: last?.timestamp ?? "0",
        fromSelf: !last || last.sender_id === user!.id || last.is_system,
      });
    }
    return out.sort((a, b) => b.ts.localeCompare(a.ts));
  }, [q.data]);

  const visible = items.filter((it) => filter === "all" || it.kind === filter);

  return (
    <div ref={pullRef} className="flex flex-col">
      {refreshing && <div className="flex justify-center py-3"><div className="h-5 w-5 animate-spin rounded-full border-2 border-clay/30 border-t-clay" /></div>}
      <div className="px-5 pb-3 pt-3">
        <h1 className="pb-3">
          <span className="font-accent text-[38px] italic text-clayDeep">{t("Messages")}</span>
        </h1>
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { value: "all", label: t("All") },
            { value: "dm", label: t("DMs"), badge: unreadDMCount },
            { value: "plan", label: t("Plans") },
          ]}
        />
      </div>

      {q.isLoading ? (
        <Spinner />
      ) : visible.length === 0 ? (
        <EmptyState
          title={t("No messages yet")}
          message={t("Join a plan or message an organiser to start a thread.")}
          emoji="💬"
        />
      ) : (
        <div className="divide-y divide-fog">
          {visible.map((it) => {
            const chatId = it.kind === "dm" ? `dm-${it.id}` : `plan-${it.id}`;
            const unread = !it.fromSelf && isUnread(chatId, it.ts);
            return (
              <button
                key={`${it.kind}-${it.id}`}
                onClick={() => nav(it.kind === "dm" ? `/dm/${it.id}` : `/plan/${it.id}`)}
                className="flex w-full items-center gap-3 px-5 py-3 text-left"
              >
                <Avatar name={it.title} url={it.avatar} plan={it.kind === "plan"} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className={`truncate ${unread ? "font-semibold text-ink" : "font-medium text-ink"}`}>{it.title}</span>
                    {it.kind === "plan" && <span className="text-[11px] text-inkMuted">{it.subtitle}</span>}
                  </div>
                  <div className={`truncate text-[13px] ${unread ? "text-ink" : "text-inkMuted"}`}>{it.preview}</div>
                </div>
                {unread && <span className="ml-1 h-2.5 w-2.5 shrink-0 rounded-full bg-clay" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

function Avatar({ name, url, plan }: { name: string; url: string | null; plan: boolean }) {
  if (url) return <img src={url} alt="" className="h-11 w-11 rounded-full object-cover" />;
  return (
    <div className={`flex h-11 w-11 items-center justify-center rounded-full text-[15px] text-cream ${plan ? "bg-sageDeep" : "bg-clay"}`}>
      {plan ? "🍽️" : name.charAt(0).toUpperCase()}
    </div>
  );
}
