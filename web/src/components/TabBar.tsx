// Bottom tab bar — mirrors ContentView's 4 tabs (Discover / My Plans /
// Messages / Profile).
import { NavLink } from "react-router-dom";
import { t } from "@/i18n";

const TABS = [
  { to: "/discover", key: "Discover", icon: "🍴" },
  { to: "/plans", key: "My Plans", icon: "📅" },
  { to: "/messages", key: "Messages", icon: "💬" },
  { to: "/profile", key: "Profile", icon: "👤" },
];

export function TabBar() {
  return (
    <nav className="z-20 flex shrink-0 border-t border-fog bg-cream/95 pb-[env(safe-area-inset-bottom)] backdrop-blur">
      {TABS.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) =>
            `flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] ${
              isActive ? "text-clay" : "text-inkMuted"
            }`
          }
        >
          <span className="text-[20px] leading-none">{tab.icon}</span>
          <span className="font-semibold">{t(tab.key)}</span>
        </NavLink>
      ))}
    </nav>
  );
}
