// Mirrors AuthViewModel + AuthService.swift: anonymous bootstrap on load,
// email/password sign-up that *converts* the anonymous account in place and
// requires email confirmation, and confirmation-gated sign-in.

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { supabase } from "@/lib/supabase";
import { setAnalyticsUser } from "@/lib/analytics";
import type { AppUser } from "@/types";

interface AuthState {
  user: AppUser | null;
  loading: boolean;
  /** Non-anonymous, real account. */
  isSignedIn: boolean;
  /** Set after sign-up when email confirmation is pending. */
  pendingConfirmationEmail: string | null;
  signUp: (email: string, password: string, displayName: string) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  resendConfirmation: () => Promise<void>;
  clearPending: () => void;
  refresh: () => Promise<void>;
  /** Send a password-reset email (link returns to the site for a new password). */
  resetPassword: (email: string) => Promise<void>;
  /** Set a new password during a recovery session, then finish signing in. */
  updatePassword: (newPassword: string) => Promise<void>;
  /** True while the user is in the password-recovery flow (arrived via reset link). */
  passwordRecovery: boolean;
}

const Ctx = createContext<AuthState | null>(null);
export const useAuth = () => {
  const v = useContext(Ctx);
  if (!v) throw new Error("useAuth outside provider");
  return v;
};

class AuthError extends Error {
  needsConfirmation = true;
}

/** get-or-create the users row (mirrors ensureUserProfileExists). A blank
 *  display_name lets the DB trigger assign a sequential "Diner<member_no>". */
async function ensureProfile(uid: string, email: string, displayName = ""): Promise<AppUser> {
  const existing = await supabase.from("users").select("*").eq("id", uid).limit(1);
  if (existing.data && existing.data[0]) return existing.data[0] as AppUser;
  const row = {
    id: uid,
    email,
    display_name: displayName,
    is_anonymous: email.length === 0,
  };
  await supabase.from("users").upsert(row, { onConflict: "id" });
  const fetched = await supabase.from("users").select("*").eq("id", uid).limit(1);
  return (fetched.data?.[0] as AppUser) ?? (row as AppUser);
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingConfirmationEmail, setPending] = useState<string | null>(null);
  const [passwordRecovery, setPasswordRecovery] = useState(false);

  async function loadProfile(uid: string, email: string, confirmed: boolean, isAnon: boolean) {
    const profile = await ensureProfile(uid, email);
    // Auth state is the source of truth for "real account" (mirrors restoreSession):
    profile.is_anonymous = isAnon || !confirmed;
    setUser(profile);
    setAnalyticsUser(profile.id); // attribute analytics to this (guest or real) user

  }

  async function bootstrap() {
    const { data } = await supabase.auth.getSession();
    let s = data.session;
    if (!s) {
      const anon = await supabase.auth.signInAnonymously();
      s = anon.data.session;
    }
    if (s) {
      // Prefer the server-fresh user over the (possibly stale) cached session
      // token — after the user clicks the email link, email_confirmed_at flips
      // server-side before the local token refreshes, so getUser reflects the
      // confirmation immediately instead of after a delay.
      const { data: fresh } = await supabase.auth.getUser();
      const u = fresh.user ?? s.user;
      await loadProfile(u.id, u.email ?? "", !!u.email_confirmed_at, !!u.is_anonymous);
    }
    setLoading(false);
  }

  useEffect(() => {
    bootstrap();
    // Supabase fires PASSWORD_RECOVERY after the user returns via a reset link.
    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") setPasswordRecovery(true);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const refresh = async () => {
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      await loadProfile(
        data.user.id,
        data.user.email ?? "",
        !!data.user.email_confirmed_at,
        !!data.user.is_anonymous,
      );
    }
  };

  const signUp = async (email: string, password: string, displayName: string) => {
    setPending(null);
    const { data: sess } = await supabase.auth.getSession();
    const wasAnon = !!sess.session?.user.is_anonymous;
    let uid: string;
    let needsConfirmation: boolean;

    if (wasAnon) {
      const { data, error } = await supabase.auth.updateUser({ email, password });
      if (error) throw error;
      uid = data.user.id;
      needsConfirmation = !data.user.email_confirmed_at;
    } else {
      const { data, error } = await supabase.auth.signUp({ email, password });
      if (error) throw error;
      uid = data.user!.id;
      needsConfirmation = !data.session;
    }

    await ensureProfile(uid, email, displayName);
    // Keep is_anonymous = true until confirmed (so the app doesn't treat an
    // unconfirmed account as signed in — mirrors promoteProfile).
    await supabase
      .from("users")
      .update({ email, display_name: displayName, is_anonymous: needsConfirmation })
      .eq("id", uid);

    if (needsConfirmation) {
      setPending(email);
      throw new AuthError("Please check your email to confirm your account before signing in.");
    }
    await refresh();
  };

  const signIn = async (email: string, password: string) => {
    setPending(null);
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    if (!data.user.email_confirmed_at) {
      await supabase.auth.signOut();
      throw new AuthError("Please check your email to confirm your account before signing in.");
    }
    await supabase.from("users").update({ is_anonymous: false }).eq("id", data.user.id);
    await refresh();
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setPending(null);
    await bootstrap(); // re-establish an anonymous session for guest browsing
  };

  const resendConfirmation = async () => {
    if (!pendingConfirmationEmail) return;
    await supabase.auth.resend({ type: "signup", email: pendingConfirmationEmail });
  };

  const resetPassword = async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: typeof window !== "undefined" ? window.location.origin : undefined,
    });
    if (error) throw error;
  };

  const updatePassword = async (newPassword: string) => {
    const { data, error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
    // The recovery session is a real account — flip it non-anonymous and reload.
    if (data.user) {
      await supabase.from("users").update({ is_anonymous: false }).eq("id", data.user.id);
    }
    setPasswordRecovery(false);
    await refresh();
  };

  const isSignedIn = !!user && user.is_anonymous === false;

  return (
    <Ctx.Provider
      value={{
        user,
        loading,
        isSignedIn,
        pendingConfirmationEmail,
        signUp,
        signIn,
        signOut,
        resendConfirmation,
        clearPending: () => setPending(null),
        refresh,
        resetPassword,
        updatePassword,
        passwordRecovery,
      }}
    >
      {children}
    </Ctx.Provider>
  );
}
