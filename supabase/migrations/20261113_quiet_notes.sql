-- A note between two people. It settles later, and it stays unopened
-- until the recipient actually opens it. Chat stays a separate table.

CREATE TABLE IF NOT EXISTS public.quiet_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivers_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '4 hours'),
  opened_at TIMESTAMPTZ,
  CONSTRAINT quiet_notes_not_self CHECK (from_user_id <> to_user_id),
  CONSTRAINT quiet_notes_body_length CHECK (char_length(btrim(body)) BETWEEN 1 AND 500)
);

CREATE INDEX IF NOT EXISTS quiet_notes_inbox_idx
  ON public.quiet_notes (to_user_id, delivers_at)
  WHERE opened_at IS NULL;

CREATE INDEX IF NOT EXISTS quiet_notes_pair_idx
  ON public.quiet_notes (from_user_id, to_user_id, created_at);

ALTER TABLE public.quiet_notes ENABLE ROW LEVEL SECURITY;

-- The sender can see what they wrote, including notes still on their way.
-- The recipient only sees a note once it has settled.
DROP POLICY IF EXISTS "People can read their notes" ON public.quiet_notes;
CREATE POLICY "People can read their notes" ON public.quiet_notes
  FOR SELECT TO authenticated
  USING (
    from_user_id = auth.uid()
    OR (to_user_id = auth.uid() AND delivers_at <= now())
  );

DROP POLICY IF EXISTS "People can leave a note" ON public.quiet_notes;
CREATE POLICY "People can leave a note" ON public.quiet_notes
  FOR INSERT TO authenticated
  WITH CHECK (from_user_id = auth.uid() AND to_user_id <> auth.uid());

-- Opening a note goes through open_quiet_note, so a recipient cannot edit the words.
REVOKE ALL ON public.quiet_notes FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.quiet_notes TO authenticated;

CREATE OR REPLACE FUNCTION public.settle_quiet_note()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  earliest timestamptz := now() + interval '4 hours';
  latest timestamptz := now() + interval '20 hours';
BEGIN
  NEW.body := btrim(COALESCE(NEW.body, ''));
  IF char_length(NEW.body) < 1 OR char_length(NEW.body) > 500 THEN
    RAISE EXCEPTION 'A note needs between 1 and 500 characters';
  END IF;
  IF NEW.from_user_id = NEW.to_user_id THEN
    RAISE EXCEPTION 'A note needs another person';
  END IF;
  IF NEW.delivers_at IS NULL OR NEW.delivers_at < earliest THEN
    NEW.delivers_at := earliest;
  ELSIF NEW.delivers_at > latest THEN
    NEW.delivers_at := latest;
  END IF;
  NEW.opened_at := NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS quiet_notes_settle ON public.quiet_notes;
CREATE TRIGGER quiet_notes_settle
  BEFORE INSERT ON public.quiet_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.settle_quiet_note();

CREATE OR REPLACE FUNCTION public.open_quiet_note(note_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.quiet_notes
  SET opened_at = COALESCE(opened_at, now())
  WHERE id = note_id
    AND to_user_id = auth.uid()
    AND delivers_at <= now();
END;
$$;

REVOKE ALL ON FUNCTION public.open_quiet_note(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_quiet_note(UUID) TO authenticated;
