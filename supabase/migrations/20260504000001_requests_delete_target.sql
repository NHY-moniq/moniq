-- target_user_id(swap 대상자)도 본인 관련 요청을 삭제할 수 있도록 정책 추가
-- 기존 "Users can delete own requests"(requester) + "Team admins can delete any requests"(admin)에 더해
-- 본인이 target인 경우(swap 대상자)에도 삭제 허용.

CREATE POLICY "Users can delete requests they target"
  ON public.requests FOR DELETE
  USING (target_user_id = auth.uid());
