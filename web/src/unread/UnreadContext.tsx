// Mirrors UnreadManager.swift: tracks unread DMs, unread plan messages, unread
// plan *actions* (system joins/leaves), and the user's open-plan bucket counts.
// "Last seen" per chat lives in localStorage; realtime inserts trigger a
// recompute so the tab badges update even from another tab.
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import {
  fetchMyOpenPlans,
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
  /** Plan IDs that have unread chat messages or system actions since last seen. */
  unreadPlanIds: Set<string>;
  /** chatId is `plan-<planId>` or `dm-<otherUserId>`. */
  isUnread: (chatId: string, lastActivityISO: string) => boolean;
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
  });
  // Bump to force isUnread consumers to recompute after markRead.
  const [, setTick] = useState(0);
  const running = useRef(false);

  const refresh = useCallback(async () => {
    if (!uid || running.current) return;
    running.current = true;
    try {
      const [openPlans, dms] = await Promise.all([fetchMyOpenPlans(uid), fetchConversations(uid)]);
      const planIds = openPlans.map((p) => p.id);
      const [latest, systemMsgs] = await Promise.all([
        fetchLatestMessages(planIds),
        fetchSystemMessages(planIds),
      ]);

      let unreadPlans = 0;
      let unreadDMs = 0;
      let unreadActions = 0;
      let active = 0;
      let ready = 0;
      const unreadPlanIds = new Set<string>();

      for (const m of systemMsgs) {
        if (m.timestamp > lastSeen(`plan-${m.plan_id}`)) {
          unreadActions += 1;
          unreadPlanIds.add(m.plan_id);
        }
      }
      for (const p of openPlans) {
        if (needsMorePeople(p) > 0) active += 1;
        else ready += 1;
        const m = latest[p.id];
        if (!m || m.sender_id === uid || m.is_system) continue;
        if (m.timestamp > lastSeen(`plan-${p.id}`)) {
          unreadPlans += 1;
          unreadPlanIds.add(p.id);
        }
      }
      for (const d of dms) {
        if (d.lastSenderId === uid) continue;
        if (d.lastTimestamp > lastSeen(`dm-${d.otherUserId}`)) unreadDMs += 1;
      }

      setCounts({
        totalUnread: unreadPlans + unreadDMs,
        unreadDMCount: unreadDMs,
        unreadActionCount: unreadActions,
        activeCount: active,
        readyToGoCount: ready,
        unreadPlanIds,
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
      setTick((t) => t + 1);
      refresh();
    },
    [refresh],
  );

  const isUnread = useCallback((chatId: string, lastActivityISO: string) => lastActivityISO > lastSeen(chatId), []);

  return <Ctx.Provider value={{ ...counts, isUnread, markRead }}>{children}</Ctx.Provider>;
}
