-- Push notifications (#37).
--
-- Notification rows are still written only by database triggers. This
-- migration widens what those triggers cover and hands every new row to
-- bookbridge-rust-core, which sends it through FCM:
--   * notify_payment_confirmed now covers every purchase status change the
--     user cares about (held, successful, disputed, refunded, failed), not
--     just 'successful'.
--   * notify_new_inquiry now notifies whoever receives a message, so replies
--     to buyers are delivered as well as inquiries to sellers.
--   * An AFTER INSERT statement trigger on notifications calls
--     /internal/push/dispatch through pg_net, and a cron job retries anything
--     still unsent every two minutes.
--
-- The X-Internal-Secret value comes from the Vault secret
-- 'internal_api_secret', which must match INTERNAL_API_SECRET on Render.
-- Pushes are only sent once FCM_SERVICE_ACCOUNT_JSON is set on Render; until
-- then the dispatcher leaves rows unsent and the in-app list still works.
-- Rows still unsent after a day are closed as 'expired' rather than pushed
-- late.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'internal_api_secret') THEN
    RAISE EXCEPTION 'Vault secret internal_api_secret is missing; create it before applying this migration';
  END IF;
END $$;

-- 1. Delivery state ----------------------------------------------------------
-- push_sent_at is set once the dispatcher is done with a row. push_error is
-- null when the push was delivered, otherwise it says why it was not
-- ('no_token', 'expired', or the last FCM error after the final attempt).
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS push_sent_at  timestamptz,
  ADD COLUMN IF NOT EXISTS push_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS push_error    text;

-- Rows from before this migration were never meant to be pushed.
UPDATE public.notifications SET push_sent_at = now() WHERE push_sent_at IS NULL;

CREATE INDEX IF NOT EXISTS notifications_push_pending_idx
  ON public.notifications (created_at)
  WHERE push_sent_at IS NULL;

-- Clients only ever mark notifications read; the delivery columns are the
-- dispatcher's.
REVOKE UPDATE ON public.notifications FROM anon, authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;

-- 2. Purchase status notifications ------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_payment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  book TEXT;
  payload JSONB;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT title INTO book FROM public.listings WHERE id = NEW.listing_id;
  book := '"' || COALESCE(book, 'your book') || '"';
  payload := jsonb_build_object(
    'transaction_id', NEW.id::text,
    'listing_id',     NEW.listing_id::text,
    'status',         NEW.status
  );

  IF NEW.status = 'held' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
      (NEW.buyer_id, 'payment_confirmed', 'Payment received 🔒',
       'Your payment for ' || book || ' is held safely in escrow. Meet the seller, then confirm receipt in the app.',
       payload),
      (NEW.seller_id, 'payment_confirmed', 'You made a sale! 💰',
       'A buyer paid for ' || book || '. The money is held in escrow until they confirm receipt. Arrange a safe meetup.',
       payload);

  ELSIF NEW.status = 'successful' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
      (NEW.buyer_id, 'payment_confirmed', 'Purchase complete ✅',
       'Your purchase of ' || book || ' is complete. Thanks for using BookBridge!',
       payload),
      (NEW.seller_id, 'payment_confirmed', 'Payment released 💸',
       'The payment for ' || book || ' has been sent to your payout number.',
       payload);

  ELSIF NEW.status = 'disputed' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
      (NEW.buyer_id, 'payment_confirmed', 'Dispute received',
       'We received your report about ' || book || '. The payment stays in escrow while our team reviews it.',
       payload),
      (NEW.seller_id, 'payment_confirmed', 'Dispute opened ⚠️',
       'The buyer reported a problem with ' || book || '. The payment stays in escrow while our team reviews it.',
       payload);

  ELSIF NEW.status = 'refunded' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
      (NEW.buyer_id, 'payment_confirmed', 'Refund sent',
       'Your payment for ' || book || ' has been refunded.',
       payload),
      (NEW.seller_id, 'payment_confirmed', 'Sale refunded',
       'After review, the payment for ' || book || ' was refunded to the buyer.',
       payload);

  ELSIF NEW.status = 'failed' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data) VALUES
      (NEW.buyer_id, 'payment_confirmed', 'Payment not completed',
       'Your payment for ' || book || ' could not be completed. If money left your account, it will be refunded.',
       payload);
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_payment_confirmed_notify ON public.transactions;
CREATE TRIGGER trg_payment_confirmed_notify
  AFTER INSERT OR UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.notify_payment_confirmed();

-- 3. Message notifications ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_new_inquiry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  book TEXT;
  owner_id UUID;
  preview TEXT;
BEGIN
  IF NEW.receiver_id IS NULL OR NEW.receiver_id = NEW.sender_id THEN
    RETURN NEW;
  END IF;

  SELECT title, seller_id INTO book, owner_id FROM public.listings WHERE id = NEW.listing_id;
  preview := left(NEW.content, 120);
  IF length(NEW.content) > 120 THEN
    preview := preview || '…';
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.receiver_id,
    CASE WHEN NEW.receiver_id = owner_id THEN 'new_inquiry' ELSE 'new_message' END,
    CASE WHEN NEW.receiver_id = owner_id
      THEN 'New inquiry about "' || COALESCE(book, 'your book') || '"'
      ELSE 'New message about "' || COALESCE(book, 'a book') || '"'
    END,
    preview,
    jsonb_build_object(
      'listing_id', NEW.listing_id::text,
      'sender_id',  NEW.sender_id::text
    )
  );

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_new_inquiry_notify ON public.messages;
CREATE TRIGGER trg_new_inquiry_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_inquiry();

-- 4. Hand new rows to the dispatcher ----------------------------------------
-- pg_net queues the request and sends it after this transaction commits, so
-- the dispatcher sees the rows. If the call is lost, the cron job below
-- picks the rows up.
CREATE OR REPLACE FUNCTION public.dispatch_push_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM inserted_rows WHERE push_sent_at IS NULL) THEN
    PERFORM net.http_post(
      url     := 'https://bookbridge-rust-core.onrender.com/internal/push/dispatch',
      headers := jsonb_build_object(
        'Content-Type',      'application/json',
        'X-Internal-Secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'internal_api_secret' LIMIT 1)
      ),
      body    := '{}'::jsonb
    );
  END IF;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_dispatch_push_notifications ON public.notifications;
CREATE TRIGGER trg_dispatch_push_notifications
  AFTER INSERT ON public.notifications
  REFERENCING NEW TABLE AS inserted_rows
  FOR EACH STATEMENT EXECUTE FUNCTION public.dispatch_push_notifications();

SELECT cron.unschedule('push-dispatch-retry-job') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'push-dispatch-retry-job'
);

SELECT cron.schedule(
  'push-dispatch-retry-job',
  '*/2 * * * *',
  $$
  SELECT net.http_post(
    url     := 'https://bookbridge-rust-core.onrender.com/internal/push/dispatch',
    headers := jsonb_build_object(
      'Content-Type',      'application/json',
      'X-Internal-Secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'internal_api_secret' LIMIT 1)
    ),
    body    := '{}'::jsonb
  )
  WHERE EXISTS (SELECT 1 FROM public.notifications WHERE push_sent_at IS NULL);
  $$
);

-- 5. Trigger functions are not client-callable ------------------------------
DO $$
DECLARE
  fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.notify_payment_confirmed()',
    'public.notify_new_inquiry()',
    'public.dispatch_push_notifications()'
  ]
  LOOP
    IF to_regprocedure(fn) IS NOT NULL THEN
      EXECUTE format('revoke execute on function %s from public, anon, authenticated', fn);
    END IF;
  END LOOP;
END $$;
