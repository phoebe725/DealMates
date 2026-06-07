-- Tie analytics events to the actual (guest or registered) user so activity is
-- attributable. user_id is the auth uid (lowercase uuid string); join to
-- public.users to resolve member_no / display_name. Screen-time is logged as
-- session_start / session_heartbeat / session_end events (duration in metadata).
alter table public.analytics_events add column if not exists user_id text;
create index if not exists idx_analytics_events_user on public.analytics_events (user_id);
