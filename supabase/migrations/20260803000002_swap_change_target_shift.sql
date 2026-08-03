-- =============================================================================
-- 멤버 간 근무 변경(swap) 의미 변경: "신청자와 맞교환" → "대상 멤버의 근무 변경"
--
-- 기존(20260803000001): 신청자 ↔ 대상자의 해당 날짜 근무를 서로 맞바꿈
-- 변경: 대상 멤버의 해당 날짜 근무를 요청된 근무로 변경한다.
--       신청자의 근무는 건드리지 않는다.
--   - requested_shift_type_id IS NULL  → 대상의 그 날짜 근무 삭제 (오프로 변경)
--   - 대상에게 그 날짜 근무가 있으면   → shift_type_id 변경
--   - 대상이 오프(근무 행 없음)면     → 해당 날짜를 포함하는 최신 발행
--                                        근무표에 새 근무 행 추가
-- swap 외 분기(day_off / shift_change)는 기존과 동일.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.apply_request(p_request_id UUID)
RETURNS JSONB AS $$
DECLARE
  r RECORD;
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

  -- 3) 멤버 근무 변경 — 대상 멤버의 그 날짜 근무를 요청된 근무로 변경
  ELSIF r.change_type = 'swap' THEN
    IF r.target_user_id IS NULL OR r.requested_date IS NULL THEN
      RAISE EXCEPTION 'swap requires target_user_id and requested_date';
    END IF;

    IF r.requested_shift_type_id IS NULL THEN
      -- 오프로 변경: 대상의 그 날짜 근무 삭제
      DELETE FROM public.shifts
       WHERE team_id = r.team_id
         AND user_id = r.target_user_id
         AND shift_date = r.requested_date;
    ELSE
      UPDATE public.shifts
         SET shift_type_id = r.requested_shift_type_id
       WHERE team_id = r.team_id
         AND user_id = r.target_user_id
         AND shift_date = r.requested_date;
      IF NOT FOUND THEN
        -- 대상이 오프(근무 행 없음): 해당 날짜를 포함하는 최신 발행 근무표에 추가
        INSERT INTO public.shifts
          (schedule_id, team_id, user_id, shift_date, shift_type_id)
        SELECT sch.id, r.team_id, r.target_user_id, r.requested_date,
               r.requested_shift_type_id
          FROM public.schedules sch
         WHERE sch.team_id = r.team_id
           AND sch.status = 'published'
           AND r.requested_date BETWEEN sch.period_start AND sch.period_end
         ORDER BY sch.version_no DESC
         LIMIT 1;
        IF NOT FOUND THEN
          RAISE EXCEPTION '해당 날짜를 포함하는 발행된 근무표가 없어 근무를 추가할 수 없습니다';
        END IF;
      END IF;
    END IF;
    RETURN jsonb_build_object('applied', 'swap');

  -- 4) 그 외
  ELSE
    RAISE EXCEPTION 'change_type % is not auto-appliable', r.change_type;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.apply_request(UUID) TO authenticated;
