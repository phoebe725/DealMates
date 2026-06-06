import Foundation

// MARK: - Config
// Replace these with your Supabase project values.
// Dashboard → your project → Settings → API
enum Config {
    static let supabaseURL     = "https://wvnebxkhyepfbtxajcih.supabase.co/"
    static let supabaseAnonKey = "sb_publishable_e6-F9NamL1s2kgxFGQ4gyw_p0j5Q1Oo"

    /// Founder account that may open the admin view (long-press the Profile
    /// wordmark). Compared case-insensitively against the signed-in email.
    /// Change this single constant to hand the admin view to a different owner.
    static let founderEmail = "phoebe880725@gmail.com"
}
