-- Personal team appointments.
-- A private-team member can create an appointment for selected team members;
-- the RPC writes matching rows into each participant's personal_events.

CREATE TABLE IF NOT EXISTS public.personal_team_appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  event_date DATE NOT NULL,
  start_time TEXT,
  end_time TEXT,
  description TEXT,
  color TEXT,
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_team_appointments_team_date
  ON public.personal_team_appointments(team_id, event_date);

CREATE TABLE IF NOT EXISTS public.personal_team_appointment_participants (
  appointment_id UUID NOT NULL REFERENCES public.personal_team_appointments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  personal_event_id UUID REFERENCES public.personal_events(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (appointment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_personal_team_appointment_participants_user
  ON public.personal_team_appointment_participants(user_id);

ALTER TABLE public.personal_team_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_team_appointment_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members can view personal team appointments"
  ON public.personal_team_appointments FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.team_members tm
      WHERE tm.team_id = personal_team_appointments.team_id
        AND tm.user_id = auth.uid()
        AND tm.is_deleted = false
    )
  );

CREATE POLICY "Team members can view appointment participants"
  ON public.personal_team_appointment_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.personal_team_appointments a
      JOIN public.team_members tm ON tm.team_id = a.team_id
      WHERE a.id = personal_team_appointment_participants.appointment_id
        AND tm.user_id = auth.uid()
        AND tm.is_deleted = false
    )
  );

CREATE OR REPLACE FUNCTION public.create_personal_team_appointment(
  p_team_id UUID,
  p_event_date DATE,
  p_title TEXT,
  p_participant_ids UUID[],
  p_start_time TEXT DEFAULT NULL,
  p_end_time TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_color TEXT DEFAULT '#FFB800'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_appointment_id UUID;
  v_user_id UUID;
  v_event_id UUID;
  v_invalid_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.team_members tm
    WHERE tm.team_id = p_team_id
      AND tm.user_id = auth.uid()
      AND tm.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'Not a team member';
  END IF;

  IF p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'Title is required';
  END IF;

  IF COALESCE(array_length(p_participant_ids, 1), 0) = 0 THEN
    RAISE EXCEPTION 'At least one participant is required';
  END IF;

  SELECT count(*)
  INTO v_invalid_count
  FROM (
    SELECT DISTINCT participant_id
    FROM unnest(p_participant_ids) AS p(participant_id)
  ) p
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.team_members tm
    WHERE tm.team_id = p_team_id
      AND tm.user_id = p.participant_id
      AND tm.is_deleted = false
  );

  IF v_invalid_count > 0 THEN
    RAISE EXCEPTION 'Invalid participant';
  END IF;

  INSERT INTO public.personal_team_appointments (
    team_id,
    title,
    event_date,
    start_time,
    end_time,
    description,
    color,
    created_by
  )
  VALUES (
    p_team_id,
    btrim(p_title),
    p_event_date,
    p_start_time,
    p_end_time,
    p_description,
    p_color,
    auth.uid()
  )
  RETURNING id INTO v_appointment_id;

  FOR v_user_id IN
    SELECT DISTINCT participant_id
    FROM unnest(p_participant_ids) AS p(participant_id)
  LOOP
    INSERT INTO public.personal_events (
      user_id,
      event_date,
      title,
      start_time,
      end_time,
      description,
      color,
      recurrence
    )
    VALUES (
      v_user_id,
      p_event_date,
      btrim(p_title),
      p_start_time,
      p_end_time,
      p_description,
      p_color,
      'none'
    )
    RETURNING id INTO v_event_id;

    INSERT INTO public.personal_team_appointment_participants (
      appointment_id,
      user_id,
      personal_event_id
    )
    VALUES (
      v_appointment_id,
      v_user_id,
      v_event_id
    );
  END LOOP;

  RETURN v_appointment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_personal_team_appointment(
  UUID,
  DATE,
  TEXT,
  UUID[],
  TEXT,
  TEXT,
  TEXT,
  TEXT
) TO authenticated;

NOTIFY pgrst, 'reload schema';
