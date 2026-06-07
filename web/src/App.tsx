import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "@/auth/AuthContext";
import { trackPageView, startScreenTimeTracking } from "@/lib/analytics";
import { TabBar } from "@/components/TabBar";
import { Wordmark } from "@/components/ui";
import { SignedOut, SetNewPassword } from "@/screens/SignedOut";
import { Discover } from "@/screens/Discover";
import { RestaurantBoard } from "@/screens/RestaurantBoard";
import { PlanDetail } from "@/screens/PlanDetail";
import { CreatePlan } from "@/screens/CreatePlan";
import { MyPlans } from "@/screens/MyPlans";
import { Messages } from "@/screens/Messages";
import { DMChat } from "@/screens/DMChat";
import { Profile } from "@/screens/Profile";
import { UserProfile } from "@/screens/UserProfile";

function Splash() {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-4">
      <Wordmark size={44} />
      <div className="h-5 w-5 animate-spin rounded-full border-2 border-inkMuted/30 border-t-inkMuted" />
    </div>
  );
}

/** Tab routes show the bottom bar; detail routes (restaurant/plan) don't. */
function Shell() {
  const { pathname } = useLocation();
  const { user } = useAuth();
  const nav = useNavigate();
  // Once a guest signs in (becomes a real, confirmed account), leave the auth
  // screen for Discover — mirrors the app, where auth state flips you straight
  // back into the tabs. Email-confirm signups stay anonymous until verified, so
  // this correctly leaves them on the "check your inbox" screen.
  useEffect(() => {
    if (pathname === "/signin" && user && user.is_anonymous === false) {
      nav("/discover", { replace: true });
    }
  }, [pathname, user, nav]);
  const showTabs = ["/discover", "/plans", "/messages", "/profile"].includes(pathname);
  return (
    <div className="flex h-full flex-col">
      <main className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden">
        <Routes>
          <Route path="/" element={<Navigate to="/discover" replace />} />
          <Route path="/discover" element={<Discover />} />
          <Route path="/plans" element={<MyPlans />} />
          <Route path="/messages" element={<Messages />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/restaurant/:id" element={<RestaurantBoard />} />
          <Route path="/plan/:id" element={<PlanDetail />} />
          <Route path="/dm/:id" element={<DMChat />} />
          <Route path="/user/:id" element={<UserProfile />} />
          <Route path="/create" element={<CreatePlan />} />
          <Route path="/signin" element={<div className="h-full overflow-y-auto"><SignedOut /></div>} />
          <Route path="*" element={<Navigate to="/discover" replace />} />
        </Routes>
      </main>
      {showTabs && <TabBar />}
    </div>
  );
}

export default function App() {
  const { loading, user, passwordRecovery } = useAuth();
  const { pathname } = useLocation();

  // page_view on every route change.
  useEffect(() => {
    trackPageView(pathname);
  }, [pathname]);

  // Screen-time: session_start + heartbeat while visible + session_end on close.
  useEffect(() => startScreenTimeTracking(), []);

  // Keep the shell sized to the *visual* viewport so the on-screen keyboard
  // shrinks it (iOS Safari doesn't shrink dvh/vh for the keyboard), and scroll a
  // newly-focused input into view once the keyboard has animated in — so the
  // field is never hidden behind it.
  useEffect(() => {
    const vv = window.visualViewport;
    const root = document.documentElement;
    const setH = () => root.style.setProperty("--app-height", `${vv ? vv.height : window.innerHeight}px`);
    setH();
    vv?.addEventListener("resize", setH);
    vv?.addEventListener("scroll", setH);
    window.addEventListener("resize", setH);

    const onFocusIn = (e: FocusEvent) => {
      const el = e.target as HTMLElement | null;
      if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA")) {
        setTimeout(() => el.scrollIntoView({ block: "center", behavior: "smooth" }), 250);
      }
    };
    document.addEventListener("focusin", onFocusIn);

    return () => {
      vv?.removeEventListener("resize", setH);
      vv?.removeEventListener("scroll", setH);
      window.removeEventListener("resize", setH);
      document.removeEventListener("focusin", onFocusIn);
    };
  }, []);

  return (
    <div className="pin-shell">
      {loading ? (
        <Splash />
      ) : passwordRecovery ? (
        // Arrived via a password-reset link — set a new password before anything else.
        <div className="h-full overflow-y-auto">
          <SetNewPassword />
        </div>
      ) : user ? (
        // Both anonymous guests and signed-in users get the full Shell.
        // Action gates (join, create, DM) prompt sign-up inline when needed.
        <Shell />
      ) : (
        <div className="h-full overflow-y-auto">
          <SignedOut />
        </div>
      )}
    </div>
  );
}
