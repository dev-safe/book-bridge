-- #64: remove the hardcoded broadcast secret from notify_impact_milestone_fcm.
--
-- The prod function fell back to a literal secret when the
-- app.broadcast_secret setting was missing. It now reads the secret from
-- Vault (name 'broadcast_secret') and skips the call if the secret is not
-- set. search_path is pinned and clients cannot execute the function.
--
-- Before applying, store the rotated secret in Vault:
--   SELECT vault.create_secret('<new secret>', 'broadcast_secret');
-- and set the same value on the broadcast-milestone edge function.

CREATE OR REPLACE FUNCTION public.notify_impact_milestone_fcm()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  old_count  integer := COALESCE(OLD.total_books_circulated, 0);
  new_count  integer := COALESCE(NEW.total_books_circulated, 0);
  milestones integer[] := ARRAY[10, 50, 100, 250, 500, 1000, 2000, 5000];
  milestone  integer;
  secret     text;
BEGIN
  IF new_count <= old_count THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO secret
  FROM vault.decrypted_secrets
  WHERE name = 'broadcast_secret'
  LIMIT 1;

  IF secret IS NULL THEN
    RAISE WARNING 'broadcast_secret missing from vault; milestone broadcast skipped';
    RETURN NEW;
  END IF;

  FOREACH milestone IN ARRAY milestones LOOP
    IF old_count < milestone AND new_count >= milestone THEN
      PERFORM net.http_post(
        url     := 'https://jacnsvcwmhoicuuzmrmr.supabase.co/functions/v1/broadcast-milestone',
        headers := jsonb_build_object(
          'Content-Type',       'application/json',
          'x-broadcast-secret', secret
        ),
        body    := jsonb_build_object(
          'milestone',        milestone,
          'books_circulated', new_count
        )
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_impact_milestone_fcm ON public.platform_stats;
CREATE TRIGGER trg_impact_milestone_fcm
  AFTER UPDATE ON public.platform_stats
  FOR EACH ROW EXECUTE FUNCTION public.notify_impact_milestone_fcm();

REVOKE EXECUTE ON FUNCTION public.notify_impact_milestone_fcm()
  FROM PUBLIC, anon, authenticated;
