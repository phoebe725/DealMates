// Mirrors UnreadManager.swift: tracks unread DMs, unread plan messages, unread
// plan *actions* (system joins/leaves), and the user's open-plan bucket counts.
// "Last seen" per chat lives in localStorage; realtime inserts trigger a
// recompute so the tab badges update even from another tab.
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import {
  fetchMyPlans,
  fetchConversations,
  fetchLatestMessages,
  fetchSystemMessages,
  listenToAllMessageInserts,
  listenToAllDMInserts,
  listenToAllPlanChanges,
} from "@/services/db";
import { needsMorePeople } from "@/types";
import { useAuth } from "@/auth/AuthContext";

interface UnreadState {
  /** Unread DMs + unread plan messages — the Messages tab badge. */
  totalUnread: number;
  /** Unread DM conversations only — next to the "DMs" filter. */
  unreadDMCount: number;
  /** Unread plan actions (joins/leaves) — the My Plans tab badge. */
  unreadActionCount: number;
  /** Open plans still recruiting / full-but-unconfirmed. */
  activeCount: number;
  readyToGoCount: number;
  /** Plan IDs with unread chat messages or system actions since last seen. */
  unreadPlanIds: Set<string>;
  /** Other-user IDs of DM threads with unread messages since last seen. */
  unreadDmIds: Set<string>;
  markRead: (chatId: string) => void;
}

const EPOCH = "1970-01-01T00:00:00.000Z";
const key = (chatId: string) => `unread.lastSeen.${chatId}`;
const lastSeen = (chatId: string) => localStorage.getItem(key(chatId)) ?? EPOCH;

const Ctx = createContext<UnreadState | null>(null);
export const useUnread = () => {
  const v = useContext(Ctx);
  if (!v) throw new Error("useUnread outside provider");
  return v;
};

export function UnreadProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const uid = user?.id ?? "";
  const [counts, setCounts] = useState({
    totalUnread: 0,
    unreadDMCount: 0,
    unreadActionCount: 0,
    activeCount: 0,
    readyToGoCount: 0,
    unreadPlanIds: new Set<string>(),
    unreadDmIds: new Set<string>(),
  });
  const running = useRef(false);

  const refresh = useCallback(async () => {
    if (!uid || running.current) return;
    running.current = true;
    try {
      // Single source of truth: ALL the user's plans — the same set the
      // Messages and My Plans lists render. A narrower set would count a plan
      // the Messages list doesn't show (the badge/row mismatch bug).
      const [allPlans, dms] = await Promise.all([fetchMyPlans(uid), fetchConversations(uid)]);
      const planIds = allPlans.map((p) => p.id);
      const [latest, systemMsgs] = await Promise.all([
        fetchLatestMessages(planIds),
        fetchSystemMessages(planIds),
      ]);

      let unreadActions = 0;
      let active = 0;
      let ready = 0;
      const unreadPlanIds = new Set<string>();
      const unreadDmIds = new Set<string>();

      for (const m of systemMsgs) {
        if (m.timestamp > lastSeen(`plan-${m.plan_id}`)) {
          unreadActions += 1;
          unreadPlanIds.add(m.plan_id);
        }
      }
      for (const p of allPlans) {
        // Active / Ready buckets only count plans still open (attendance not
        // confirmed) — matches MyPlans bucketing.
        if (!p.attendance_confirmed_at) {
          if (needsMorePeople(p) > 0) active += 1;
          else ready += 1;
        }
        const m = latest[p.id];
        // Own messages are never unread. System messages already handled above.
        if (!m || m.sender_id === uid || m.is_system) continue;
        if (m.timestamp > lastSeen(`plan-${p.id}`)) {
          unreadPlanIds.add(p.id);
        }
      }
      for (const d of dms) {
        if (d.lastSenderId === uid) continue;
        if (d.lastTimestamp > lastSeen(`dm-${d.otherUserId}`)) unreadDmIds.add(d.otherUserId);
      }

      // Badge = exactly the rows that get a dot. Both derive from the same sets.
      setCounts({
        totalUnread: unreadPlanIds.size + unreadDmIds.size,
        unreadDMCount: unreadDmIds.size,
        unreadActionCount: unreadActions,
        activeCount: active,
        readyToGoCount: ready,
        unreadPlanIds,
        unreadDmIds,
      });
    } catch {
      // Keep previous counts on a network blip — never flash to zero.
    } finally {
      running.current = false;
    }
  }, [uid]);

  // Initial + on user change.
  useEffect(() => {
    if (uid) refresh();
  }, [uid, refresh]);

  // Realtime: any new message / DM / plan change recomputes.
  useEffect(() => {
    if (!uid) return;
    const offs = [
      listenToAllMessageInserts(refresh),
      listenToAllDMInserts(refresh),
      listenToAllPlanChanges(refresh),
    ];
    return () => offs.forEach((off) => off());
  }, [uid, refresh]);

  const markRead = useCallback(
    (chatId: string) => {
      localStorage.setItem(key(chatId), new Date().toISOString());
      refresh();
    },
    [refresh],
  );

  return <Ctx.Provider value={{ ...counts, markRead }}>{children}</Ctx.Provider>;
}
