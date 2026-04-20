-- =============================================================================
-- 근무 변경 요청 자동 적용
--   (a) requests 테이블에 target_user_id 추가 (1:1 swap 상대방)
--   (b) apply_request(request_id) RPC — 승인된 요청을 shifts에 실제 반영
--
-- 정책:
--   - day_off:       requester의 requested_date shift 삭제
--   - shift_change:  requester의 requested_date shift_type_id 변경
--   - swap:          requester ↔ target_user 같은 requested_date에서 shift_type 교환
--                    (양쪽 모두 그 날 shift가 있어야 성공. 한쪽 없으면 RAISE)
--   - schedule_change: 자동 적용 미지원 (관리자가 직접 처리)
--
-- 호출자:
--   - 클라이언트가 status = 'approved'로 업데이트 후 RPC 호출
--   - SECURITY DEFINER로 동작 (RLS 우회 — RPC 자체는 admin만 호출하도록 가드)
-- =============================================================================

ALTER TABLE public.requests
  ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS idx_requests_target_user
  ON public.requests(target_user_id)
  WHERE target_user_id IS NOT NULL;

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

  -- 3) 교환 — 양쪽 같은 날짜의 shift_type 교환
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

    IF v_my_shift_id IS NULL OR v_target_shift_id IS NULL THEN
      RAISE EXCEPTION '양쪽 모두 해당 날짜에 shift가 있어야 교환 가능';
    END IF;

    UPDATE public.shifts SET shift_type_id = v_target_type WHERE id = v_my_shift_id;
    UPDATE public.shifts SET shift_type_id = v_my_type    WHERE id = v_target_shift_id;
    RETURN jsonb_build_object('applied', 'swap');

  -- 4) 그 외
  ELSE
    RAISE EXCEPTION 'change_type % is not auto-appliable', r.change_type;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.apply_request(UUID) TO authenticated;
