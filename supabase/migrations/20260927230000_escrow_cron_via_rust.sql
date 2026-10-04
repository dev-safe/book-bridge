-- Records the escrow cron jobs as they already run in production: both call
-- bookbridge-rust-core instead of the process-escrow / fapshi-polling edge
-- functions scheduled in 20260611180000. Re-running this recreates the same
-- jobs; it does not change live behaviour.
--
-- The X-Internal-Secret value comes from the Vault secret
-- 'internal_api_secret', which must match INTERNAL_API_SECRET on Render.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'internal_api_secret') THEN
    RAISE EXCEPTION 'Vault secret internal_api_secret is missing; create it before applying this migration';
  END IF;
END $$;

SELECT cron.unschedule('auto-release-escrows-job') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'auto-release-escrows-job'
);

SELECT cron.schedule(
  'auto-release-escrows-job',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url     := 'https://bookbridge-rust-core.onrender.com/internal/escrow/process-releases',
    headers := jsonb_build_object(
      'Content-Type',      'application/json',
      'X-Internal-Secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'internal_api_secret' LIMIT 1)
    ),
    body    := '{}'::jsonb
  );
  $$
);

SELECT cron.unschedule('fapshi-polling-job') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'fapshi-polling-job'
);

SELECT cron.schedule(
  'fapshi-polling-job',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url     := 'https://bookbridge-rust-core.onrender.com/internal/escrow/poll-pending',
    headers := jsonb_build_object(
      'Content-Type',      'application/json',
      'X-Internal-Secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'internal_api_secret' LIMIT 1)
    ),
    body    := '{}'::jsonb
  );
  $$
);
