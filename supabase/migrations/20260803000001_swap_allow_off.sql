-- =============================================================================
-- 멤버 간 근무 교환(swap)에서 오프(휴무)인 팀원과의 교환 허용
--
-- 기존: 양쪽 모두 해당 날짜에 shift가 있어야 교환 가능 (한쪽 없으면 RAISE)
-- 변경: 한쪽만 근무가 있으면 그 근무를 상대에게 넘긴다 —
--       근무자는 오프가 되고, 오프였던 사람이 근무를 받는다.
--       (shifts 행의 user_id만 변경하므로 schedule_id 연결은 보존됨)
-- 양쪽 모두 근무가 없으면 교환할 것이 없으므로 기존처럼 RAISE.
-- swap 외 분기(day_off / shift_change)는 20260421000001과 동일.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.apply_request(p_request_id UUID)
RETURNS JSONB AS $$
DECLARE
  r RECORD;
  v_my_shift_id UUID;
  v_target_shift_id UUID;
  v_my_type UUID;
  v_target_type UUID;
  v_caller UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_caller := auth.uid();
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT * INTO r FROM public.requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request not found';
  END IF;

  -- 호출자가 해당 팀 관리자인지 확인
  SELECT EXISTS (
    SELECT 1 FROM public.team_members
    WHERE team_id = r.team_id
      AND user_id = v_caller
      AND role = 'admin'
      AND NOT is_deleted
  ) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'not a team admin';
  END IF;

  IF r.status <> 'approved' THEN
    RAISE EXCEPTION 'request status must be approved (current: %)', r.status;
  END IF;

  -- 1) 휴무 요청 — 본인 그 날짜 shift 삭제
  IF r.change_type = 'day_off' THEN
    IF r.requested_date IS NULL THEN
      RAISE EXCEPTION 'requested_date is null for day_off';
    END IF;
    DELETE FROM public.shifts
     WHERE team_id = r.team_id
       AND user_id = r.requester_user_id
       AND shift_date = r.requested_date;
    RETURN jsonb_build_object('applied', 'day_off');

  -- 2) 근무 변경 — 본인 그 날짜 shift_type_id 변경
  ELSIF r.change_type = 'shift_change' THEN
    IF r.requested_date IS NULL OR r.requested_shift_type_id IS NULL THEN
      RAISE EXCEPTION 'requested_date or requested_shift_type_id is null';
    END IF;
    UPDATE public.shifts
       SET shift_type_id = r.requested_shift_type_id
     WHERE team_id = r.team_id
       AND user_id = r.requester_user_id
       AND shift_date = r.requested_date;
    RETURN jsonb_build_object('applied', 'shift_change');

  -- 3) 교환 — 양쪽 근무 교환. 한쪽이 오프면 근무를 넘겨준다.
  ELSIF r.change_type = 'swap' THEN
    IF r.target_user_id IS NULL OR r.requested_date IS NULL THEN
      RAISE EXCEPTION 'swap requires target_user_id and requested_date';
    END IF;

    SELECT id, shift_type_id INTO v_my_shift_id, v_my_type
      FROM public.shifts
     WHERE team_id = r.team_id
       AND user_id = r.requester_user_id
       AND shift_date = r.requested_date
     LIMIT 1;

    SELECT id, shift_type_id INTO v_target_shift_id, v_target_type
      FROM public.shifts
     WHERE team_id = r.team_id
       AND user_id = r.target_user_id
       AND shift_date = r.requested_date
     LIMIT 1;

    IF v_my_shift_id IS NULL AND v_target_shift_id IS NULL THEN
      RAISE EXCEPTION '두 사람 모두 해당 날짜에 근무가 없어 교환할 수 없습니다';
    ELSIF v_my_shift_id IS NOT NULL AND v_target_shift_id IS NOT NULL THEN
      -- 양쪽 모두 근무: 기존과 동일하게 shift_type 맞교환
      UPDATE public.shifts SET shift_type_id = v_target_type WHERE id = v_my_shift_id;
      UPDATE public.shifts SET shift_type_id = v_my_type    WHERE id = v_target_shift_id;
    ELSIF v_my_shift_id IS NOT NULL THEN
      -- 상대가 오프: 내 근무를 상대에게 넘기고 나는 오프가 된다
      UPDATE public.shifts SET user_id = r.target_user_id WHERE id = v_my_shift_id;
    ELSE
      -- 내가 오프: 상대 근무를 내가 받고 상대는 오프가 된다
      UPDATE public.shifts SET user_id = r.requester_user_id WHERE id = v_target_shift_id;
    END IF;
    RETURN jsonb_build_object('applied', 'swap');

  -- 4) 그 외
  ELSE
    RAISE EXCEPTION 'change_type % is not auto-appliable', r.change_type;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.apply_request(UUID) TO authenticated;
