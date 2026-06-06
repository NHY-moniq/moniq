-- 약속 opt-in 재설계:
-- 생성 시 전원의 개인 캘린더에 강제 주입하지 않고, 메타 + 참여자 상태만 만든다.
-- 각 참여자는 본인이 직접 "내 캘린더에 추가"를 눌러 personal_events에 반영한다.

-- 참여자별 상태: invited(대기) / added(내 캘린더 반영) / declined(참여 안 함)
ALTER TABLE public.personal_team_appointment_participants
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'invited'
  CHECK (status IN ('invited', 'added', 'declined'));

-- ── 생성: 메타 + 참여자(invited), 생성자만 added + 본인 personal_event ──
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
  v_expected_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members tm
    WHERE tm.team_id = p_team_id AND tm.user_id = auth.uid()
      AND tm.is_deleted = false
  ) THEN
    RAISE EXCEPTION 'Not a team member';
  END IF;

  IF p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'Title is required';
  END IF;

  SELECT count(*) INTO v_expected_count
  FROM (SELECT DISTINCT participant_id
        FROM unnest(p_participant_ids) AS p(participant_id)) p;
  IF v_expected_count = 0 THEN
    RAISE EXCEPTION 'At least one participant is required';
  END IF;

  SELECT count(*) INTO v_invalid_count
  FROM (SELECT DISTINCT participant_id
        FROM unnest(p_participant_ids) AS p(participant_id)) p
  WHERE NOT EXISTS (
    SELECT 1 FROM public.team_members tm
    WHERE tm.team_id = p_team_id AND tm.user_id = p.participant_id
      AND tm.is_deleted = false
  );
  IF v_invalid_count > 0 THEN
    RAISE EXCEPTION 'Invalid participant';
  END IF;

  INSERT INTO public.personal_team_appointments (
    team_id, title, event_date, start_time, end_time, description, color, created_by
  )
  VALUES (
    p_team_id, btrim(p_title), p_event_date, p_start_time, p_end_time,
    p_description, p_color, auth.uid()
  )
  RETURNING id INTO v_appointment_id;

  FOR v_user_id IN
    SELECT DISTINCT participant_id
    FROM unnest(p_participant_ids) AS p(participant_id)
  LOOP
    IF v_user_id = auth.uid() THEN
      -- 생성자: 본인 캘린더에 즉시 반영 (added)
      INSERT INTO public.personal_events (
        user_id, event_date, title, start_time, end_time, description, color, recurrence
      )
      VALUES (
        v_user_id, p_event_date, btrim(p_title), p_start_time, p_end_time,
        p_description, p_color, 'none'
      )
      RETURNING id INTO v_event_id;

      INSERT INTO public.personal_team_appointment_participants (
        appointment_id, user_id, personal_event_id, status
      )
      VALUES (v_appointment_id, v_user_id, v_event_id, 'added');
    ELSE
      -- 그 외: 초대만 (invited), 캘린더 미반영
      INSERT INTO public.personal_team_appointment_participants (
        appointment_id, user_id, personal_event_id, status
      )
      VALUES (v_appointment_id, v_user_id, NULL, 'invited');
    END IF;
  END LOOP;

  RETURN v_appointment_id;
END;
$$;

-- ── 내 캘린더에 추가 (invited/declined → added) ──
CREATE OR REPLACE FUNCTION public.add_appointment_to_my_calendar(p_appointment_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_event_id UUID;
  v_existing public.personal_team_appointment_participants%ROWTYPE;
  v_appt public.personal_team_appointments%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_existing FROM public.personal_team_appointment_participants
  WHERE appointment_id = p_appointment_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not a participant'; END IF;
  IF v_existing.personal_event_id IS NOT NULL THEN
    RETURN v_existing.personal_event_id; -- 이미 추가됨
  END IF;

  SELECT * INTO v_appt FROM public.personal_team_appointments
  WHERE id = p_appointment_id;

  INSERT INTO public.personal_events (
    user_id, event_date, title, start_time, end_time, description, color, recurrence
  )
  VALUES (
    v_uid, v_appt.event_date, v_appt.title, v_appt.start_time, v_appt.end_time,
    v_appt.description, v_appt.color, 'none'
  )
  RETURNING id INTO v_event_id;

  UPDATE public.personal_team_appointment_participants
  SET status = 'added', personal_event_id = v_event_id
  WHERE appointment_id = p_appointment_id AND user_id = v_uid;

  RETURN v_event_id;
END;
$$;

-- ── 내 캘린더에서 빼기 (added → invited) ──
CREATE OR REPLACE FUNCTION public.remove_appointment_from_my_calendar(p_appointment_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_existing public.personal_team_appointment_participants%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_existing FROM public.personal_team_appointment_participants
  WHERE appointment_id = p_appointment_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Not a participant'; END IF;

  IF v_existing.personal_event_id IS NOT NULL THEN
    DELETE FROM public.personal_events
    WHERE id = v_existing.personal_event_id AND user_id = v_uid;
  END IF;

  UPDATE public.personal_team_appointment_participants
  SET status = 'invited', personal_event_id = NULL
  WHERE appointment_id = p_appointment_id AND user_id = v_uid;
END;
$$;

-- ── 약속 삭제 (생성자만): 전원 personal_events 제거 후 약속 삭제 ──
CREATE OR REPLACE FUNCTION public.delete_personal_team_appointment(p_appointment_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_appt public.personal_team_appointments%ROWTYPE;
BEGIN
  SELECT * INTO v_appt FROM public.personal_team_appointments
  WHERE id = p_appointment_id;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_appt.created_by <> auth.uid() THEN
    RAISE EXCEPTION 'Only the creator can delete this appointment';
  END IF;

  DELETE FROM public.personal_events pe
  USING public.personal_team_appointment_participants p
  WHERE p.appointment_id = p_appointment_id
    AND p.personal_event_id = pe.id;

  DELETE FROM public.personal_team_appointments WHERE id = p_appointment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_appointment_to_my_calendar(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_appointment_from_my_calendar(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_personal_team_appointment(UUID) TO authenticated;
