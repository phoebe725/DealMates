// Bottom tab bar — mirrors ContentView's 4 tabs (Discover / My Plans /
// Messages / Profile), with unread badges on My Plans (plan actions) and
// Messages (unread DMs + plan messages).
import { NavLink } from "react-router-dom";
import { t } from "@/i18n";
import { useUnread } from "@/unread/UnreadContext";

export function TabBar() {
  const { totalUnread, unreadActionCount } = useUnread();
  const tabs = [
    { to: "/discover", key: "Discover", icon: "🍴", badge: 0 },
    { to: "/plans", key: "My Plans", icon: "📅", badge: unreadActionCount },
    { to: "/messages", key: "Messages", icon: "💬", badge: totalUnread },
    { to: "/profile", key: "Profile", icon: "👤", badge: 0 },
  ];

  return (
    <nav className="z-20 flex shrink-0 border-t border-fog bg-cream/95 pb-[env(safe-area-inset-bottom)] backdrop-blur">
      {tabs.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) =>
            `flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] ${
              isActive ? "text-clay" : "text-inkMuted"
            }`
          }
        >
          <span className="relative text-[20px] leading-none">
            {tab.icon}
            {tab.badge > 0 && (
              <span className="absolute -right-2.5 -top-1 inline-flex min-w-[16px] items-center justify-center rounded-full bg-clay px-1 text-[10px] font-semibold leading-[16px] text-cream">
                {tab.badge > 99 ? "99+" : tab.badge}
              </span>
            )}
          </span>
          <span className="font-semibold">{t(tab.key)}</span>
        </NavLink>
      ))}
    </nav>
  );
}
