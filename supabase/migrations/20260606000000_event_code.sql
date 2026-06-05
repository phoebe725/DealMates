-- Short event code for linkless sharing (e.g. PT482).
ALTER TABLE plans ADD COLUMN IF NOT EXISTS event_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS plans_event_code_idx
  ON plans (event_code) WHERE event_code IS NOT NULL;
