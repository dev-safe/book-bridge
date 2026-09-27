-- Move the hourly auto-release job off the process-escrow edge function and
-- onto bookbridge-rust-core. Rust's release path requires both the
-- transaction and escrow rows to be 'held' and checks Fapshi for an existing
-- payout before paying (GHSA-xq84-qm9j-hf6p).
--
-- Apply only after the Rust service with /internal/escrow/process-releases is
-- deployed. First store the service's INTERNAL_API_SECRET (from Render) in Vault:
--   SELECT vault.create_secret('<INTERNAL_API_SECRET>', 'rust_internal_api_secret');

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'rust_internal_api_secret') THEN
    RAISE EXCEPTION 'Vault secret rust_internal_api_secret is missing; create it before applying this migration';
  END IF;
END $$;

SELECT cron.unschedule('auto-release-escrows-job') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'auto-release-escrows-job'
);

-- The long timeout covers Render free-tier cold starts (up to about a minute).
SELECT cron.schedule(
  'auto-release-escrows-job',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://bookbridge-rust-core.onrender.com/internal/escrow/process-releases',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Internal-Secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'rust_internal_api_secret' LIMIT 1)
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
