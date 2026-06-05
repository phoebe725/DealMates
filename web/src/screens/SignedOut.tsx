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
      <div className="flex min-h-full flex-col items-center justify-center px-8 text-center">
        <Wordmark size={40} />
        <h1 className="mt-10 leading-tight">
          <span className="font-sans text-[30px] font-light text-ink">{t("Find a ")}</span>
          <span className="font-accent text-[40px] italic text-clayDeep">{t("Table")}</span>
        </h1>
        <p className="mt-2 font-subtitle text-[15px] text-inkMuted">
          {t("Find people to share group dining deals.")}
        </p>
        <div className="mt-10 w-full space-y-3">
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
  const { signUp: doSignUp, signIn } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

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
          <input
            className="pin-field"
            type="password"
            placeholder={t("At least 8 characters")}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field>
      </div>

      {error && <p className="mt-4 rounded-pin bg-clay/12 p-3 text-[13px] text-ink">{error}</p>}

      <button className="pin-btn-primary mt-6" disabled={!canSubmit || busy} onClick={submit}>
        {busy ? "…" : signUp ? t("Pin me in") : t("Sign in")}
      </button>

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
        {t("Tap the link we sent to %@ to finish setting up your account.", pendingConfirmationEmail ?? "")}
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="block space-y-2">
      <span className="text-[14px] font-medium text-ink">{label}</span>
      {children}
    </label>
  );
}
