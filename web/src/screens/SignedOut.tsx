// Mirrors SignedOutFlow + LaunchView + LoginView: launch hero → sign up / sign
// in form → "Check your inbox" confirmation gate.
import { useState } from "react";
import { useAuth } from "@/auth/AuthContext";
import { t } from "@/i18n";
import { Wordmark } from "@/components/ui";

type Stage = "launch" | "form";

export function SignedOut() {
  const { pendingConfirmationEmail } = useAuth();
  const [stage, setStage] = useState<Stage>("launch");
  const [signUp, setSignUp] = useState(true);

  if (pendingConfirmationEmail) return <CheckInbox />;

  if (stage === "launch") {
    return (
      <div className="flex min-h-full flex-col items-center justify-between px-8 pb-10 pt-6 text-center">
        {/* Hero illustration + wordmark */}
        <div className="flex flex-col items-center">
          <img
            src="/launch-hero.png"
            alt=""
            className="w-48 max-w-[60vw] object-contain"
            draggable={false}
          />
          <Wordmark size={44} />
        </div>

        {/* Tagline */}
        <div className="space-y-2">
          <h1 className="leading-tight">
            <span className="font-sans text-[30px] font-light text-ink">{t("Deals. Tables.")}</span>
            <br />
            <span className="font-accent text-[40px] italic text-clayDeep">{t("Together.")}</span>
          </h1>
          <p className="font-subtitle text-[15px] text-inkMuted">
            {t("Discover restaurant deals and build your table.")}
          </p>
        </div>

        {/* CTAs */}
        <div className="w-full space-y-3">
          <button className="pin-btn-primary" onClick={() => { setSignUp(true); setStage("form"); }}>
            {t("Sign up")}
          </button>
          <button className="pin-btn-secondary" onClick={() => { setSignUp(false); setStage("form"); }}>
            {t("I already have an account")}
          </button>
        </div>
      </div>
    );
  }

  return <AuthForm signUp={signUp} setSignUp={setSignUp} onBack={() => setStage("launch")} />;
}

function AuthForm({
  signUp,
  setSignUp,
  onBack,
}: {
  signUp: boolean;
  setSignUp: (v: boolean) => void;
  onBack: () => void;
}) {
  const { signUp: doSignUp, signIn, resetPassword } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resetSent, setResetSent] = useState(false);
  const [busy, setBusy] = useState(false);

  async function forgotPassword() {
    if (!email) {
      setError(t("Enter your email first to reset your password."));
      return;
    }
    setError(null);
    try {
      await resetPassword(email);
      setResetSent(true);
    } catch (e: any) {
      setError(e?.message ?? "Something went wrong.");
    }
  }

  const canSubmit = email && password && (!signUp || name);

  async function submit() {
    setError(null);
    setBusy(true);
    try {
      if (signUp) await doSignUp(email, password, name);
      else await signIn(email, password);
    } catch (e: any) {
      // AuthError (needs confirmation) flips to CheckInbox via context state.
      if (!e?.needsConfirmation) setError(e?.message ?? "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="px-6 pt-4">
      <button onClick={onBack} className="mb-4 text-[22px] text-ink">‹</button>
      <h1 className="leading-tight">
        {signUp ? (
          <>
            <span className="font-sans text-[28px] font-light text-ink">{t("Welcome to the ")}</span>
            <span className="font-accent text-[40px] italic text-clayDeep">{t("table.")}</span>
          </>
        ) : (
          <span className="font-accent text-[40px] italic text-clayDeep">{t("Welcome back.")}</span>
        )}
      </h1>
      <p className="mb-7 font-subtitle text-[15px] text-inkMuted">
        {signUp ? t("Pin your first plan in a minute.") : t("Sign in to see your plans and chats.")}
      </p>

      <div className="space-y-4">
        {signUp && (
          <Field label={t("Your name")}>
            <input className="pin-field" placeholder="e.g., Alex" value={name} onChange={(e) => setName(e.target.value)} />
          </Field>
        )}
        <Field label={t("Email")}>
          <input
            className="pin-field"
            type="email"
            autoCapitalize="none"
            autoCorrect="off"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field>
        <Field label={t("Password")}>
          <div className="relative">
            <input
              className="pin-field pr-11"
              type={showPassword ? "text" : "password"}
              placeholder={t("At least 8 characters")}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? t("Hide password") : t("Show password")}
              className="absolute inset-y-0 right-0 flex items-center pr-3.5 text-inkMuted"
            >
              <EyeIcon off={showPassword} />
            </button>
          </div>
        </Field>
      </div>

      {error && <p className="mt-4 rounded-pin bg-clay/12 p-3 text-[13px] text-ink">{error}</p>}

      <button className="pin-btn-primary mt-6" disabled={!canSubmit || busy} onClick={submit}>
        {busy ? "…" : signUp ? t("Pin me in") : t("Sign in")}
      </button>

      {!signUp &&
        (resetSent ? (
          <p className="mt-4 text-center text-[13px] text-sageDeep">{t("Reset link sent — check your inbox.")}</p>
        ) : (
          <button className="mt-4 block w-full text-center text-[13px] font-medium text-clay" onClick={forgotPassword}>
            {t("Forgot password?")}
          </button>
        ))}

      <div className="mt-6 text-center text-[14px] text-inkMuted">
        {signUp ? t("Already have an account?") : t("Don't have an account?")}{" "}
        <button className="font-semibold text-clay" onClick={() => setSignUp(!signUp)}>
          {signUp ? t("Sign in") : t("Sign up")}
        </button>
      </div>
    </div>
  );
}

function CheckInbox() {
  const { pendingConfirmationEmail, signIn, resendConfirmation, clearPending } = useAuth();
  return (
    <div className="px-6 pt-6">
      <button onClick={clearPending} className="mb-4 text-[22px] text-ink">‹</button>
      <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-full bg-clay/15 text-2xl text-clayDeep">✉️</div>
      <h1 className="font-sans text-[28px] font-light text-ink">{t("Check your inbox")}</h1>
      <p className="mt-2 text-[15px] text-inkMuted">
        {t("Tap the link we sent to %@ to finish setting up my account.", pendingConfirmationEmail ?? "")}
      </p>
      <button className="pin-btn-primary mt-6" onClick={() => location.reload()}>
        {t("I've verified my email")}
      </button>
      <div className="mt-6 text-center text-[14px] text-inkMuted">
        {t("Didn't receive an email?")}{" "}
        <button className="font-semibold text-clay" onClick={resendConfirmation}>
          {t("Resend")}
        </button>
      </div>
    </div>
  );
}

export function SetNewPassword() {
  const { updatePassword } = useAuth();
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (password.length < 8) {
      setError(t("At least 8 characters"));
      return;
    }
    setError(null);
    setBusy(true);
    try {
      await updatePassword(password);
    } catch (e: any) {
      setError(e?.message ?? "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="px-6 pt-8">
      <h1 className="font-sans text-[28px] font-light text-ink">{t("Set a new password")}</h1>
      <div className="mt-7">
        <label className="block space-y-2">
          <span className="text-[14px] font-medium text-ink">{t("New password")}</span>
          <div className="relative">
            <input
              className="pin-field pr-11"
              type={showPassword ? "text" : "password"}
              placeholder={t("At least 8 characters")}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && submit()}
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? t("Hide password") : t("Show password")}
              className="absolute inset-y-0 right-0 flex items-center pr-3.5 text-inkMuted"
            >
              <EyeIcon off={showPassword} />
            </button>
          </div>
        </label>
      </div>

      {error && <p className="mt-4 rounded-pin bg-clay/12 p-3 text-[13px] text-ink">{error}</p>}

      <button className="pin-btn-primary mt-6" disabled={!password || busy} onClick={submit}>
        {busy ? "…" : t("Update password")}
      </button>
    </div>
  );
}

function EyeIcon({ off }: { off: boolean }) {
  return (
    <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      {off ? (
        <>
          <path d="M9.88 9.88a3 3 0 0 0 4.24 4.24" />
          <path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68" />
          <path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61" />
          <line x1="2" y1="2" x2="22" y2="22" />
        </>
      ) : (
        <>
          <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" />
          <circle cx="12" cy="12" r="3" />
        </>
      )}
    </svg>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-2">
      <span className="text-[14px] font-medium text-ink">{label}</span>
      {children}
    </label>
  );
}
