-- Structured system messages so each client can render them in its own language.
-- `system_kind` identifies which template (joined / left / left_promoted / removed),
-- `system_args` carries the actor / target user ids — names are resolved at view time
-- from the current `users` rows so renames flow through automatically.
alter table public.messages add column if not exists system_kind text;
alter table public.messages add column if not exists system_args jsonb;
