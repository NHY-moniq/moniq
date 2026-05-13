-- shift_handovers.created_by FK를 public.users(id)로 변경.
-- 기존 auth.users(id) 참조는 PostgREST resource embedding 시
-- auth 스키마 접근 제한으로 user join이 실패하여 fetch 결과가 비는 문제 해결.
-- 다른 테이블(announcements, requests, wanted 등)과 동일 패턴.

ALTER TABLE public.shift_handovers
  DROP CONSTRAINT IF EXISTS shift_handovers_created_by_fkey;

ALTER TABLE public.shift_handovers
  ADD CONSTRAINT shift_handovers_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users(id);
