// Mirrors AuthViewModel + AuthService.swift: anonymous bootstrap on load,
// email/password sign-up that *converts* the anonymous account in place and
// requires email confirmation, and confirmation-gated sign-in.

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { supabase } from "@/lib/supabase";
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

function randomDinerName() {
  return `Diner${Math.floor(100 + Math.random() * 900)}`;
}

/** get-or-create the users row (mirrors ensureUserProfileExists). */
async function ensureProfile(uid: string, email: string, displayName = ""): Promise<AppUser> {
  const existing = await supabase.from("users").select("*").eq("id", uid).limit(1);
  if (existing.data && existing.data[0]) return existing.data[0] as AppUser;
  const row = {
    id: uid,
    email,
    display_name: displayName || randomDinerName(),
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

  async function loadProfile(uid: string, email: string, confirmed: boolean, isAnon: boolean) {
    const profile = await ensureProfile(uid, email);
    // Auth state is the source of truth for "real account" (mirrors restoreSession):
    profile.is_anonymous = isAnon || !confirmed;
    setUser(profile);
  }

  async function bootstrap() {
    const { data } = await supabase.auth.getSession();
    let s = data.session;
    if (!s) {
      const anon = await supabase.auth.signInAnonymously();
      s = anon.data.session;
    }
    if (s) {
      await loadProfile(
        s.user.id,
        s.user.email ?? "",
        !!s.user.email_confirmed_at,
        !!s.user.is_anonymous,
      );
    }
    setLoading(false);
  }

  useEffect(() => {
    bootstrap();
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
      }}
    >
      {children}
    </Ctx.Provider>
  );
}
