-- Announcement Author Visibility
-- 공지 카드/상세에서 작성자(users) 조인이 항상 동작하도록 RLS를 보강한다.
--
-- 배경:
--   team_announcements / announcement_comments 조회 시 `users` 테이블을
--   조인해 작성자 display_name / avatar_url 을 함께 가져온다.
--   기존 "Users can view team members profiles" 정책은 대상 유저의
--   team_members 행이 NOT is_deleted 인 경우에만 프로필을 노출하므로,
--   팀을 탈퇴한 작성자의 프로필이 NULL 로 내려와 "알 수 없음" 으로 표시된다.
--
-- 해결:
--   내가 속한 팀의 공지/댓글을 작성한 유저라면, 현재 멤버십 상태와
--   무관하게 해당 유저의 public.users 프로필을 SELECT 할 수 있게 한다.
--   (display_name / avatar_url 만 노출되며, 이미 같은 팀 컨텍스트에서
--    공지를 볼 수 있는 사용자에게만 적용되므로 정보 노출 범위가 넓어지지 않는다.)

-- 공지 작성자 프로필 조회 허용
CREATE POLICY "Users can view announcement authors"
  ON public.users FOR SELECT
  USING (
    id IN (
      SELECT ta.created_by
      FROM public.team_announcements ta
      WHERE ta.team_id IN (SELECT get_my_team_ids())
    )
  );

-- 공지 댓글 작성자 프로필 조회 허용
CREATE POLICY "Users can view announcement comment authors"
  ON public.users FOR SELECT
  USING (
    id IN (
      SELECT ac.user_id
      FROM public.announcement_comments ac
      WHERE ac.team_id IN (SELECT get_my_team_ids())
    )
  );

-- 참고:
--   PostgreSQL RLS 의 복수 SELECT 정책은 OR 로 결합되므로,
--   기존 "Users can view own profile" / "Users can view team members profiles"
--   정책과 함께 적용된다. 기존 정책 파일은 수정하지 않는다.
