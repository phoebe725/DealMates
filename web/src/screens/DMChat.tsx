// Mirrors DMChatView: 1:1 direct-message thread with realtime updates.
import { useEffect, useRef, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  fetchDirectMessages,
  sendDirectMessage,
  listenToDirectMessages,
  fetchUsers,
} from "@/services/db";
import type { DirectMessage, AppUser } from "@/types";
import { t } from "@/i18n";
import { useAuth } from "@/auth/AuthContext";
import { Spinner } from "@/components/ui";

export function DMChat() {
  const { id: otherId = "" } = useParams();
  const nav = useNavigate();
  const { user } = useAuth();

  const [messages, setMessages] = useState<DirectMessage[] | null>(null);
  const [other, setOther] = useState<AppUser | null>(null);
  const [draft, setDraft] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!user || !otherId) return;
    fetchDirectMessages(user.id, otherId).then(setMessages).catch(() => setMessages([]));
    fetchUsers([otherId]).then((u) => setOther(u[0] ?? null)).catch(() => {});
    const off = listenToDirectMessages(user.id, otherId, (m) =>
      setMessages((prev) => (prev?.some((x) => x.id === m.id) ? prev : [...(prev ?? []), m])),
    );
    return off;
  }, [user?.id, otherId]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages?.length]);

  async function send() {
    const text = draft.trim();
    if (!text || !user || !other) return;
    setDraft("");
    await sendDirectMessage(user, { id: other.id, name: other.display_name, avatar: other.avatar_url ?? null }, text);
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-fog bg-shell px-4 py-3">
        <button onClick={() => nav(-1)} className="text-[22px] text-ink">‹</button>
        <button
          onClick={() => otherId && nav(`/user/${otherId}`)}
          className="flex-1 truncate text-center font-medium text-ink"
        >
          {other?.display_name ?? ""}
        </button>
        <span className="w-6" />
      </div>

      {messages === null ? (
        <Spinner />
      ) : (
        <div ref={scrollRef} className="flex-1 space-y-2 overflow-y-auto px-5 py-4">
          {messages.map((m) => {
            const mine = m.sender_id === user?.id;
            return (
              <div key={m.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[78%] rounded-2xl px-3 py-2 text-[14px] ${mine ? "bg-clay text-cream" : "bg-shell text-ink"}`}>
                  {m.text}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div className="flex items-center gap-2 border-t border-fog bg-cream px-4 py-3">
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
    </div>
  );
}
