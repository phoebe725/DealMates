-- Weekly schedule for the refresh-deals edge function (Sunday 02:00 UTC).
--
-- Uses pg_cron to fire and pg_net to make the HTTPS call to the function. The
-- function authenticates with the project service-role key, which we read from
-- Vault at call time rather than hardcoding it into this migration.
--
-- ──────────────────────────────────────────────────────────────────────────
-- ONE-TIME SETUP (run once in the dashboard SQL editor before this helps):
--
--   1. Enable the extensions (Database → Extensions, or):
--        create extension if not exists pg_cron;
--        create extension if not exists pg_net;
--
--   2. Store the service-role key in Vault (Project Settings → Vault):
--        select vault.create_secret(
--          '<YOUR_SERVICE_ROLE_KEY>', 'service_role_key',
--          'Service role key used by scheduled edge-function calls');
--
--   3. Deploy the function:  supabase functions deploy refresh-deals
--      and set its ANTHROPIC_API_KEY secret.
-- ──────────────────────────────────────────────────────────────────────────

-- Idempotent (re)schedule: drop any existing job of the same name first.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'refresh-deals-weekly') then
    perform cron.unschedule('refresh-deals-weekly');
  end if;
end $$;

select cron.schedule(
  'refresh-deals-weekly',
  '0 2 * * 0',  -- 02:00 UTC every Sunday
  $$
  select net.http_post(
    url     := 'https://wvnebxkhyepfbtxajcih.supabase.co/functions/v1/refresh-deals',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'
      )
    ),
    body    := '{}'::jsonb
  );
  $$
);
