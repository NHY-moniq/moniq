-- =============================================================================
-- is_shift 재백필
--
-- 앱이 반복 전개본을 만들 때 isShift를 복사하지 않아, 1차 백필(…0002) 이후에
-- 저장된 근무들이 다시 is_shift=false로 쌓였다. 클라이언트 수정과 함께
-- 같은 기준으로 한 번 더 맞춘다.
--
-- 기준은 1차와 동일: 제목이 실제 근무 유형 이름과 같은 일정(오프 제외).
-- =============================================================================

UPDATE public.personal_events pe
   SET is_shift = true
 WHERE pe.is_shift = false
   AND (
     EXISTS (
       SELECT 1 FROM public.shift_types st
        WHERE st.name = pe.title
     )
     OR pe.title IN ('데이', '이브닝', '나이트', '교육')
   )
   AND pe.title NOT IN ('오프', '오프(휴무)', 'OFF', 'Off', 'off');
