-- Ensure private-team appointments are written to every selected participant's
-- personal calendar, not only the caller's calendar.

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
SET row_security = off
AS $$
DECLARE
  v_appointment_id UUID;
  v_user_id UUID;
  v_event_id UUID;
  v_invalid_count INT;
  v_expected_count INT;
  v_inserted_count INT := 0;
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

  SELECT count(*)
  INTO v_expected_count
  FROM (
    SELECT DISTINCT participant_id
    FROM unnest(p_participant_ids) AS p(participant_id)
  ) p;

  IF v_expected_count = 0 THEN
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

    v_inserted_count := v_inserted_count + 1;
  END LOOP;

  IF v_inserted_count <> v_expected_count THEN
    RAISE EXCEPTION
      'Appointment sync mismatch: expected %, inserted %',
      v_expected_count,
      v_inserted_count;
  END IF;

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
