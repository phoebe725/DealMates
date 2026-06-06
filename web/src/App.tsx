import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { useAuth } from "@/auth/AuthContext";
import { trackPageView } from "@/lib/analytics";
import { TabBar } from "@/components/TabBar";
import { Wordmark } from "@/components/ui";
import { SignedOut } from "@/screens/SignedOut";
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
  const { loading, user } = useAuth();
  const { pathname } = useLocation();

  // page_view on every route change.
  useEffect(() => {
    trackPageView(pathname);
  }, [pathname]);

  return (
    <div className="pin-shell">
      {loading ? (
        <Splash />
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
