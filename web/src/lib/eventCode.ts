// Simple event codes for plan sharing, e.g. PT482.
// Uses crypto.getRandomValues for randomness — deterministic enough for UX,
// avoids ambiguous characters.

export function generateEventCode(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  const n = (buf[0] % 900) + 100; // 100–999
  return `PT${n}`;
}
