// refresh-deals
//
// Weekly job (scheduled via pg_cron — see the 20260601020000 migration) that
// refreshes restaurant deals from PUBLIC web sources only and parks the results
// in public.pending_deals for founder review. It never writes directly to
// restaurants.deals — approval happens in the in-app admin view.
//
// Flow per run:
//   1. Pick up to 10 restaurants that have a website_url or instagram_handle,
//      oldest last_deals_verified_at first.
//   2. Fetch public page text (the restaurant website). Instagram/Xiaohongshu/
//      WeChat/Buymeego and other auth-walled sources are skipped on purpose —
//      the founder adds those deals manually in the admin view.
//   3. Ask Claude to extract structured deals as JSON.
//   4. Insert extracted deals into pending_deals (status='pending').
//   5. Stamp last_deals_verified_at = now() on every processed restaurant,
//      whether or not deals were found.
//
// Secrets (Settings → Functions → Secrets):
//   ANTHROPIC_API_KEY
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

const BATCH = 10;
const MODEL = "claude-haiku-4-5-20251001"; // cheap, fast — fine for extraction
const MAX_CONTENT_CHARS = 12_000;

// Hosts we must never fetch (auth-walled / private). Founder curates these by hand.
const BLOCKED_HOSTS = [
  "instagram.com", "xiaohongshu.com", "xhslink.com", "wechat.com",
  "weixin.qq.com", "buymeego.com",
];

const EXTRACTION_PROMPT =
  `Extract current group dining deals, set menus, AYCE pricing, lunch specials, ` +
  `student discounts, or group offers from this page content. Return ONLY valid ` +
  `JSON in this shape:\n` +
  `[{"title": string, "detail": string, "confidence": "high" | "medium" | "low"}]\n` +
  `Set confidence by how clearly the page advertises the offer. Skip personal ` +
  `opinions or descriptions that aren't actual restaurant offerings. If no deals ` +
  `are advertised, return [].`;

interface DealOut { title: string; detail: string; confidence?: string }

function isBlocked(url: string): boolean {
  try {
    const host = new URL(url).hostname.replace(/^www\./, "");
    return BLOCKED_HOSTS.some((b) => host === b || host.endsWith("." + b));
  } catch {
    return true; // unparseable → don't fetch
  }
}

function stripHtml(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, MAX_CONTENT_CHARS);
}

async function fetchPageText(url: string): Promise<string | null> {
  if (isBlocked(url)) return null;
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "PintableDealBot/1.0 (+https://pintable.app)" },
      signal: AbortSignal.timeout(15_000),
    });
    if (!res.ok) return null;
    const ct = res.headers.get("content-type") ?? "";
    if (!ct.includes("html") && !ct.includes("text")) return null;
    return stripHtml(await res.text());
  } catch (e) {
    console.log(`[refresh-deals] fetch failed for ${url}: ${e}`);
    return null;
  }
}

async function extractDeals(pageText: string): Promise<DealOut[]> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1024,
      messages: [{
        role: "user",
        content: `${EXTRACTION_PROMPT}\n\n--- PAGE CONTENT ---\n${pageText}`,
      }],
    }),
  });
  if (!res.ok) {
    console.log(`[refresh-deals] Claude error ${res.status}: ${await res.text()}`);
    return [];
  }
  const data = await res.json();
  const text: string = data?.content?.[0]?.text ?? "[]";
  return parseDeals(text);
}

function parseDeals(text: string): DealOut[] {
  // Be forgiving: pull the first JSON array out of the response.
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end < start) return [];
  try {
    const arr = JSON.parse(text.slice(start, end + 1));
    if (!Array.isArray(arr)) return [];
    return arr
      .filter((d) => d && typeof d.title === "string" && d.title.trim())
      .map((d) => ({
        title: String(d.title).trim(),
        detail: String(d.detail ?? "").trim(),
        confidence: ["high", "medium", "low"].includes(d.confidence) ? d.confidence : "low",
      }));
  } catch {
    return [];
  }
}

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: restaurants, error } = await supabase
    .from("restaurants")
    .select("id, name, website_url, instagram_handle, last_deals_verified_at")
    .or("website_url.not.is.null,instagram_handle.not.is.null")
    .order("last_deals_verified_at", { ascending: true, nullsFirst: true })
    .limit(BATCH);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }

  let processed = 0;
  let inserted = 0;

  for (const r of restaurants ?? []) {
    processed++;
    try {
      // website is the only public source we hold a URL for. (TimeOut /
      // Tastecard listings would slot in here if/when their URLs are stored.)
      const pageText = r.website_url ? await fetchPageText(r.website_url) : null;
      if (pageText && pageText.length > 80) {
        const deals = await extractDeals(pageText);
        if (deals.length) {
          const rows = deals.map((d) => ({
            restaurant_id: r.id,
            title: d.title,
            detail: d.detail,
            source: "website",
            confidence: d.confidence ?? "low",
            status: "pending",
          }));
          const { error: insErr } = await supabase.from("pending_deals").insert(rows);
          if (insErr) console.log(`[refresh-deals] insert failed for ${r.id}: ${insErr.message}`);
          else inserted += rows.length;
        }
      }
    } catch (e) {
      console.log(`[refresh-deals] error for ${r.id}: ${e}`);
    }
    // Always stamp freshness so the batch rotates to other restaurants next run.
    await supabase.from("restaurants")
      .update({ last_deals_verified_at: new Date().toISOString() })
      .eq("id", r.id);
  }

  return new Response(
    JSON.stringify({ processed, pending_deals_inserted: inserted }),
    { headers: { "content-type": "application/json" } },
  );
});
