import { createClient } from "@supabase/supabase-js";

// Same Supabase project + publishable (anon) key as the iOS app
// (DealMates/Config.swift). RLS protects the data; this key is safe in the
// browser. Override via Vite env (VITE_SUPABASE_*) for other environments.
const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || "https://wvnebxkhyepfbtxajcih.supabase.co";
const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  "sb_publishable_e6-F9NamL1s2kgxFGQ4gyw_p0j5Q1Oo";

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
