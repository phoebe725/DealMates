// Bottom tab bar — mirrors ContentView's 4 tabs (Discover / My Plans /
// Messages / Profile), with unread badges on My Plans (plan actions) and
// Messages (unread DMs + plan messages). Icons mirror the app's SF Symbols
// (fork.knife / calendar / chat bubbles / person) as clean line icons that
// inherit the active/inactive tint via currentColor.
import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { t } from "@/i18n";
import { useUnread } from "@/unread/UnreadContext";

const svgProps = {
  width: 23,
  height: 23,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

// fork.knife
function DiscoverIcon() {
  return (
    <svg {...svgProps}>
      <path d="M3 2v7c0 1.1.9 2 2 2a2 2 0 0 0 2-2V2" />
      <path d="M7 2v20" />
      <path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7" />
    </svg>
  );
}

// calendar
function PlansIcon() {
  return (
    <svg {...svgProps}>
      <path d="M8 2v4" />
      <path d="M16 2v4" />
      <rect width="18" height="18" x="3" y="4" rx="2" />
      <path d="M3 10h18" />
    </svg>
  );
}

// bubble.left.and.bubble.right
function MessagesIcon() {
  return (
    <svg {...svgProps}>
      <path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2z" />
      <path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1" />
    </svg>
  );
}

// person
function ProfileIcon() {
  return (
    <svg {...svgProps}>
      <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}

export function TabBar() {
  const { totalUnread, unreadActionCount } = useUnread();
  const tabs: { to: string; key: string; icon: ReactNode; badge: number }[] = [
    { to: "/discover", key: "Discover", icon: <DiscoverIcon />, badge: 0 },
    { to: "/plans", key: "My Plans", icon: <PlansIcon />, badge: unreadActionCount },
    { to: "/messages", key: "Messages", icon: <MessagesIcon />, badge: totalUnread },
    { to: "/profile", key: "Profile", icon: <ProfileIcon />, badge: 0 },
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
          <span className="relative leading-none">
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
